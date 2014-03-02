#!/bin/bash

#-------------------------------------------------------------------------------
# This script is based on the following article:
#   https://wiki.archlinux.org/index.php/Simple_Stateful_Firewall
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Shortcuts
#-------------------------------------------------------------------------------
# Iptables
IPT=/sbin/iptables
IPT_RESTORE=/sbin/iptables-restore
IPT_SAVE=/sbin/iptables-save
EMPTY_RULES=./iptables-empty.rules
jLOG='-m limit --limit 5/m --limit-burst 10 -j LOG --log-level info --log-prefix'

# Networks
# Subnet reminder:
# xxx.xxx.xxx.96/29
# 	netmask: 255.255.255.248
# 	usable IPs (6):  xxx.xxx.xxx.97 -> xxx.xxx.xxx.102
# xxx.xxx.xxx.96/28
# 	netmask: 255.255.255.240
# 	usable IPs (14): xxx.xxx.xxx.97 -> xxx.xxx.xxx.110
# xxx.xxx.xxx.96/27
# 	netmask: 255.255.255.224
# 	usable IPs (30): xxx.xxx.xxx.97 -> xxx.xxx.xxx.126
# Public
HOST='192.168.7.4'
HOST_GW='192.168.7.1'
HOST_IF='vmbr0'
# DMZ
DMZ='192.168.0.96/29'
DMZ_GW='192.168.0.1'
DMZ_IF='vmbr2'
# Intranet
INTRANET='10.0.2.96/29'
INTRANET_GW='10.0.2.1'
INTRANET_IF='vmbr1'
# Whitelist
WHITE_L=''
# Blacklist
BLACK_L=''

# Globals
proxmox_ports='8006,5900'
puppet_master='192.168.0.100'
pp_agent_ports='8140,61613'

#-------------------------------------------------------------------------------
# Host global protection
#-------------------------------------------------------------------------------
# Reset
$IPT_RESTORE < $EMPTY_RULES
# Basic setup
$IPT -N TCP
$IPT -N UDP
$IPT -N SSH
$IPT -N LOGDROP
# Basic policy
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT
$IPT -P INPUT DROP
# Input global rules
$IPT -A LOGDROP $jLOG '(SSFW)[LOGDROP]: '
$IPT -A LOGDROP -j DROP
$IPT -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A INPUT -m conntrack --ctstate INVALID -j DROP
$IPT -A INPUT -p icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT
$IPT -A INPUT -p tcp --dport ssh -m conntrack --ctstate NEW -j SSH
$IPT -A INPUT -p udp -m conntrack --ctstate NEW -j UDP
$IPT -A INPUT -p tcp --syn -m conntrack --ctstate NEW -j TCP
#$IPT -A INPUT -j LOGDROP
$IPT -A INPUT -p udp -j REJECT --reject-with icmp-port-unreachable
$IPT -A INPUT -p tcp -j REJECT --reject-with tcp-rst
$IPT -A INPUT -j REJECT --reject-with icmp-proto-unreachable
# Incoming connections
# I don't want to be locked out so firts I'll set up ssh access with some
# bruteforce protection:
# allow for three connection packets in ten seconds. Further tries in that time
# will blacklist the IP. The next rule adds a quirk by allowing a total of four
# attempts in 30 minutes.
$IPT -A SSH -m recent --name sshbf \
	--rttl --rcheck --hitcount 3 --seconds 10 -j DROP
$IPT -A SSH -m recent --name sshbf \
	--rttl --rcheck --hitcount 4 --seconds 1800 -j LOGDROP 
$IPT -A SSH $jLOG '(SSFW)[SSH]: '
$IPT -A SSH -m recent --name sshbf --set -j TCP
# TCP and UDP chains
# Allow access to Proxmox web interface:
$IPT -A TCP -d $HOST -p tcp -m multiport --dport $proxmox_ports -j ACCEPT
# Allow SSH connections
$IPT -A TCP -d $HOST -p tcp --dport ssh -j ACCEPT
# Allow access to PEConsole
$IPT -A TCP -d $HOST -p tcp --dport 4443 -j ACCEPT
$IPT -A TCP -i $INTRANET_IF $jLOG '(SSFW)[Intranet]: '
#-------------------------------------------------------------------------------
# Setting up a NAT gateway
#-------------------------------------------------------------------------------
# Basic setup
$IPT -N fw-open
$IPT -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
$IPT -A FORWARD -j fw-open 
$IPT -A FORWARD -j REJECT --reject-with icmp-host-unreach
# # Allow outgoing traffic
$IPT -t nat -A POSTROUTING -o $HOST_IF -s $DMZ -j MASQUERADE
# Allowed traffic for DMZ
$IPT -A fw-open -i $DMZ_IF -o $HOST_IF \
	-s $DMZ -p tcp --dport http -j ACCEPT
$IPT -A fw-open -i $DMZ_IF -o $HOST_IF \
	-s $DMZ -d $HOST_GW -p udp --dport 53 -j ACCEPT
$IPT -A fw-open -i $DMZ_IF $jLOG '(SSFW)[DMZ]: '
# Allow PEConsole on port 4443
$IPT -A fw-open -i $HOST_IF -o $DMZ_IF -d $puppet_master -p tcp --dport https -j ACCEPT
$IPT -t nat -A PREROUTING -i $HOST_IF -p tcp --dport 4443 -j DNAT --to $puppet_master:443
# Allowed traffic for Internal LAN
# puppet-agent
$IPT -A fw-open -i $INTRANET_IF \
	-s $INTRANET -d $puppet_master \
	-p tcp -m multiport --dport $pp_agent_ports -j ACCEPT
# apt-cacher
$IPT -A fw-open -i $INTRANET_IF -o $DMZ_IF -s $INTRANET -d $puppet_master -p tcp --dport 3142 -j ACCEPT
$IPT -A fw-open -i $INTRANET_IF $jLOG '(SSFW)[Intranet]: '
