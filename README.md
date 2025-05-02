# DDoS Protection Guide for RotMG Private Servers

Firstly, I do not claim to be good at firewalls, DDoS protection or networking in general. <br/>
But I wrote a decent set of rules which worked for DoM.

## Prerequisites:
* Know how to use a Linux VPS (I used Ubuntu)
* Know a little bit of bash scripting
* Know how to use ChatGPT for troubleshooting lol

## Basic DDoS Attack Types
### 1) SYN Packet Spam
SYN packet spam is a type of network attack where an attacker sends a large number of fake SYN requests to a server. These requests are used to start a connection, but the attacker never completes the process. This causes the server to keep resources waiting for a reply that never comes, which can slow down or crash the server. <br>
Usually, the packets in this type of attack are spoofed to look like SYN packets, but they lack the proper flags that legitimate SYN packets should have.<br>
This makes filtering them easy.

### 2) TCP_PSH,TCP_ACK Attack
The TCP_PSH, TCP_ACK attack is a type of TCP flood DDoS attack that involves a large number of packets with the PSH (Push) and ACK (Acknowledgment) flags set. <br>
TCP_PSH, TCP_ACK are legitimate flags in a normal TCP session. <br>
In this attack, the attacker sends a high volume of TCP packets with these flags without a valid connection. <br>
These packets appear to be part of an ongoing connection, which can bypass simple SYN filters (because they aren’t SYN packets). <br>

## Basic Principles

### Rate Limiting
Rate limiting is a technique used to control how many requests or packets a user or system can send within a certain time frame. <br>
It helps prevent abuse, overload, or attacks like DDoS by temporarily blocking or slowing down excessive traffic.

### Connection Tracking
Connection tracking monitors active connections to determine whether incoming packets are part of an established connection or a new one. <br>
This allows the firewall to apply different rules to new vs. existing connections.

# dom-whitelist.sh
Make sure your VPS has iptables turned on and other firewalls turned off (like ufw).<br>
<br>
The first few comment lines in the script can be entirely ignored, since they only apply to DoM.<br>
But here's a small explanation of what we do with this:<br>
```bash
# Before running this script:
ipset create dom_whitelist hash:ip hashsize 65536 maxelem 65536
```
