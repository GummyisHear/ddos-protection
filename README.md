# DDoS Protection Guide for RotMG Private Servers

Firstly, I do not claim to be good at firewalls, DDoS protection or networking in general. <br/>
But I wrote a decent set of rules which worked for DoM.

## Prerequisites:
* Know how to navigate your server source
* Know how packets work on your server
* Know how to use a Linux VPS (I used Ubuntu)
* Know a little bit of bash scripting

# IMPORTANT! Client Changes
This script simply won't work for you if you don't do these changes. <br/>

## The Problem
This script rate-limits incoming packets at a rate of 40/second. This rate is VERY low for a standard private server. <br/>
From my tests, you can easily achieve 600 packets/sec with high dex and multiple enemies on screen. <br/>
All because every time a player shoots, hits an enemy, etc the packets are sent to server instantly. You might think this is good because there won't be a delay... <br/>
But in reality the server doesn't process them instantly, instead they are all queued and processed on next server tick (how it should be). <br/>
Sending 600 packets every second is also incredibly innefficient, because every TCP packet has 40 bytes appended to it with TCP flags, so your average EnemyHit packet is not 8 bytes total, but 48! <br/>
And the final problem, rate-limiting becomes near impossible with this kind of instability. A normal player may send 600 packets, and the DDoSer may send 600. <br/>
<br/>
## The Fix
Rewrite packets which are sent to server a lot, to instead be queued on client and only sent when client receives NewTick packet. <br/>
This way you are sending one large packet every server tick instead of hundres of small ones. <br/>
<br/>
You have to rewrite the following packets:
* PlayerShoot
* PlayerHit
* EnemyHit
* Any other hits you may have (minions? static objects)
<br/>

# firewall.sh
* Make sure your VPS has iptables turned on and other firewalls turned off (like ufw).
* Remove any existing rules you may have in iptables before running this. (I explain how to do that at the bottom of the script)
* This script only covers IPv4, if your system has IPv6 enabled, you might want to disable it or write a script using ip6tables.
* Ensure that Redis is not bound to 0.0.0.0 in its config (bind 127.0.0.1)
<br/>

## Before Running

### 1. Ports
This script whitelists 2 ports: 2050 and 2051, for wServer and appEngine respectively. <br/>
You have to change them to the ports that your server is using. <br/>

### 2. RDP Port
If you have RDP set up on your VPS, uncomment this line and set your IP, so you don't get disconnected after running this.
```bash
#iptables -A INPUT -p tcp --dport 3389 -s <YOUR IP> -j ACCEPT # RDP
```

### 3. netfilter-persistent
You need this package installed, for your iptables rules to be saved after system restarts. <br/>
Don't do this if you haven't tested the rules yet. You might want the rules to get deleted when you reboot the machine if something goes wrong.<br/>
```bash
sudo apt install netfilter-persistent
```
To save rules simply run:
```bash
sudo netfilter-persistent save
sudo netfilter-persistent reload
```

## How to Run
Download the file and grant permissions to it.
```bash
sudo chmod +x ./firewall.sh
```
Then simply run it
```bash
sudo ./firewall.sh
```

# Further Actions

## Rate-Limit by Packet Size
There is a commented set of rules in the script which rate-limits connections which send too much data in a short period of time. <br/>
I haven't done enough testing with this to find good rate-limiting, and this is completely unnecessary currently. <br/>
If you want to add that to your firewall, you have to learn about packet fragmentation and do extensive testing on your server. <br/>

## OUTPUT Restrictions
This script doesn't have any rules for outbound connections, which you can add as well to further protect your system. <br/>
But that would effectively only restrict yourself in what actions you can do on the system, it wouldn't directly protect you from DDoS attacks. <br/>

## Whitelist IPs Using ipset
You can have a system which whitelists specific IP addresses, and only those would be allowed to connect to the game server. <br/>
This repository has an additional script ipset.sh which explains how to do something like that efficiently.

## OVH Edge Network Firewall
If you are an OVH customer, you can add some rules to your server which will filter packets before they even reach your server. <br/>
To access the firewall, go to your Dashboard, click on your server. Then:
* Click Network tab on the left panel
* Click IP
* Find your server in the list, click on three dots to the right of it
* Click "Edge Network Firewall configuration"
<br/>
This is the setup that I use: <br/>

![image](https://github.com/user-attachments/assets/d157c505-9f83-46f8-9eec-bdfdb94def9f)

<br/>
This firewall doesn't let you do anything advanced unfortunately, so you are basically only accepting specifics ports, and blocking everything else.<br/>
By default this Firewall is off, and only gets turned on when OVH detects a DDoS attack on your server. I have it always turned on.<br/>

