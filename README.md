# DDoS Protection Guide for RotMG Private Servers

Firstly, I do not claim to be good at firewalls, DDoS protection or networking in general. <br/>
But I wrote a decent set of rules which worked for DoM.

## Prerequisites:
* Know how to navigate your server source
* Know how packets work on your server
* Know how to use a Linux VPS (I used Ubuntu)
* Know a little bit of bash scripting

# IMPORTANT! Client Changes
This script simply won't work for you if you don't do these changes. <br>

## The Problem
This script rate-limits incoming packets at a rate of 30/second. This rate is VERY low for a standard private server. <br>
From my tests, you can easily achieve 600 packets/sec with high dex and multiple enemies on screen. <br>
All because every time a player shoots, hits an enemy, etc the packets are sent to server instantly. You might think this is good because there won't be a delay... <br>
But in reality the server doesn't process them instantly, instead they are all queued and processed on next server tick (how it should be). <br>
Sending 600 packets every second is also incredibly innefficient, because every TCP packet has 40 bytes appended to it with TCP flags, so your average EnemyHit packet is not 8 bytes total, but 48! <br>
And the final problem, rate-limiting becomes near impossible with this kind of instability. A normal player may send 600 packets, and the DDoSer may send 600. <br>
<br>
## The Fix
Rewrite packets which are sent to server a lot, to instead be queued on client and only sent when client receives NewTick packet. <br>
This way you are sending one large packet every server tick instead of hundres of small ones. <br>
<br>
You have to rewrite the following packets:
* PlayerShoot
* PlayerHit
* EnemyHit
* Any other hits you may have (minions? static objects)
<br>

# firewall.sh
Make sure your VPS has iptables turned on and other firewalls turned off (like ufw).<br>
<br>
## Before Running

### 1. Ports
This script whitelists 2 ports: 2050 and 2051, for wServer and appEngine respectively. <br>
You have to change them to the ports that your server is using. <br>

### 2. RDP Port
If you have RDP set up on your VPS, uncomment this line and set your IP, so you don't get disconnected after running this.
```bash
#iptables -A INPUT -p tcp --dport 3389 -s <YOUR IP> -j ACCEPT # RDP
```

### 3. netfilter-persistent
You need this package installed, for your iptables rules to be saved after system restarts. <br>
```bash
sudo apt install netfilter-perstent
```
To save rules simply run:
```bash
netfilter-persistent save
netfilter-persistent reload
```



