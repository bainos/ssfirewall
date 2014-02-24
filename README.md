ssfirewall
==========

**Simple Stateful Firewall** - [wiki.archlinux.org](https://wiki.archlinux.org/index.php/Simple_Stateful_Firewall)

> Traffic can fall into four "state" categories: NEW, ESTABLISHED, RELATED or INVALID and this is what makes this a "stateful" firewall rather than a less secure "stateless" one.

> Because iptables processes rules in linear order, from top to bottom within a chain, it is advised to put frequently-hit rules near the start of the chain.

Description
===========

This is a work in progress ad offers really basic features.
OUTPUT policy is set to ACCEPT, so there is no filter for outgoing traffic.

**TODO:** Write documentation :P
Some ideas on how to organize things

**Purposes:** basic security set up for web hosting.
 
Set up one proxy dedicated to http/https traffic management.
The proxy has a public IP and is exposed directly to internet.
It is located in the public network area.
It forwards allowed connections inside the DMZ area, which web servers are located in. 
Web servers are connected to intranet, where they can find database servers and perform queries.
Database servers contain critical informations and are set under strict protection.
In the DMZ area there is another server too, which act as frontend for public services needed by intranet machines, such as debian repositories.

**Network setup**

- Public
- DMZ
- Intranet

**Services**

- apt-cacher
- puppet

Features
========

- reject invalid requests on the INPUT chain
- allow specific UDP/TCP connection, such as SSH and Proxmox web interfaces/console
- basic protection against SSH bruteforce
- basic NAT setup
