ssfirewall
==========

Simple Stateful Firewall - https://wiki.archlinux.org/index.php/Simple_Stateful_Firewall

From ArchWiki:

  Traffic can fall into four "state" categories: NEW, ESTABLISHED, RELATED or INVALID and this is what makes this a "stateful" firewall rather than a less secure "stateless" one.

  Because iptables processes rules in linear order, from top to bottom within a chain, it is advised to put frequently-hit rules near the start of the chain

Description
===========

This is a work in progress ad offers really basic features.
OUTPUT policy is set to ACCEPT, so there is no filter for outgoing traffic.

Features
========

- reject invalid requests on the INPUT chain
- allow specific UDP/TCP connection, such as SSH and Proxmox web interfaces/console
- basic NAT setup
