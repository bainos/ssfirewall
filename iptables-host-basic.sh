#!/bin/bash

#-------------------------------------------------------------------------------
# This script is based on the following article:
#   https://wiki.archlinux.org/index.php/Simple_Stateful_Firewall
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# Shortcuts
#-------------------------------------------------------------------------------
IPT=/sbin/iptables
IPT_RESTORE=/sbin/iptables-restore
IPT_SAVE=/sbin/iptables-save
EMPTY_RULES=./iptables-empty.rules

HOST='192.168.7.4'
IF_HOST='bond0'
SUBNET_A='10.0.2.0/24'
IF_A='venet0'
#SUBNET_B='192.168.10.0/24'
#IF_B='venet1'
# Whitelist
WHITE_L=''
# Blacklist
BLACK_L=''

#-------------------------------------------------------------------------------
# Host global protection
#-------------------------------------------------------------------------------
# Reset
$IPT_RESTORE < $EMPTY_RULES
# Basic setup
$IPT -N TCP
$IPT -N UDP
$IPT -N IN_SSH
# Basic policy
$IPT -P FORWARD DROP
$IPT -P OUTPUT ACCEPT
$IPT -P INPUT DROP
# Input global rules
$IPT -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A INPUT -m conntrack --ctstate INVALID -j DROP
$IPT -A INPUT -p icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT
$IPT -A INPUT -p udp -m conntrack --ctstate NEW -j UDP
$IPT -A INPUT -p tcp --syn -m conntrack --ctstate NEW -j TCP
$IPT -A INPUT -p udp -j REJECT --reject-with icmp-port-unreachable
$IPT -A INPUT -p tcp -j REJECT --reject-with tcp-rst
$IPT -A INPUT -j REJECT --reject-with icmp-proto-unreachable
# Incoming connections
# I don't want to be locked out so firts I'll set up ssh access with some
# bruteforce protection:
# allow for three connection packets in ten seconds. Further tries in that time
# will blacklist the IP. The next rule adds a quirk by allowing a total of four
# attempts in 30 minutes.
$IPT -A INPUT -p tcp --dport ssh -m conntrack --ctstate NEW -j IN_SSH
$IPT -A IN_SSH -m recent --name sshbf --rttl --rcheck --hitcount 3 --seconds 10 -j DROP
$IPT -A IN_SSH -m recent --name sshbf --rttl --rcheck --hitcount 4 --seconds 1800 -j DROP 
$IPT -A IN_SSH -m recent --name sshbf --set -j ACCEPT
# TCP and UDP chains
# Allow access to Proxmox web interface:
$IPT -A TCP -d $HOST -p tcp -m multiport --dport 8006,5900 -j ACCEPT
# To accept incoming TCP connections on port 80 for a web server:
#$IPT -A TCP -p tcp --dport 80 -j ACCEPT
# To accept incoming TCP connections on port 443 for a web server (HTTPS):
#$IPT -A TCP -p tcp --dport 443 -j ACCEPT
# To allow remote SSH connections (on port 22):
#$IPT -A TCP -p tcp --dport 22 -j ACCEPT
# To accept incoming UDP streams on port 53 for a DNS server:
#$IPT -A UDP -p udp --dport 53 -j ACCEPT
#-------------------------------------------------------------------------------
# Setting up a NAT gateway
#-------------------------------------------------------------------------------
# Reset
$IPT -t nat -F
# Basic setup
$IPT -N fw-interfaces
$IPT -N fw-open
$IPT -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
$IPT -A FORWARD -j fw-interfaces 
$IPT -A FORWARD -j fw-open 
$IPT -A FORWARD -j REJECT --reject-with icmp-host-unreach
$IPT -P FORWARD DROP
# Give access to the internet
$IPT -A fw-interfaces -i $IF_A -j ACCEPT
$IPT -t nat -A POSTROUTING -s $SUBNET_A -o $IF_HOST -j MASQUERADE
#$IPT -A fw-interfaces -i $IF_B -j ACCEPT
#$IPT -t nat -A POSTROUTING -s $SUBNET_B -o $IF_HOST -j MASQUERADE
# Set up POSTROUTING chain
#$IPT -A fw-open -d 192.168.0.5 -p tcp --dport 22 -j ACCEPT
#$IPT -t nat -A PREROUTING -i ppp0 -p tcp --dport 22 -j DNAT --to 192.168.0.5
#$IPT -A fw-open -d 192.168.0.6 -p tcp --dport 80 -j ACCEPT
#$IPT -t nat -A PREROUTING -i ppp0 -p tcp --dport 8000 -j DNAT --to 192.168.0.6:80


