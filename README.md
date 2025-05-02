# DDoS Protection Guide for RotMG Private Servers

Firstly, I do not claim to be good at firewalls, DDoS protection or networking in general. <br/>
But I wrote a decent set of rules which worked for DoM.

## Prerequisites:
* Know how to program in as3 for client changes
* Know how to use a Linux VPS (I used Ubuntu)
* Know a little bit of bash scripting
* Know how to use ChatGPT for troubleshooting lol

# IMPORTANT! Client Changes
This script simply won't work for you if you don't do these changes. <br>
<br>
This script rate-limits incoming packets at a rate of 30/second. This rate is VERY low for a normal private server. <br>
From my tests, you can easily achieve 600 packets/sec with high dex and multiple enemies on screen. <br>
You have to rewrite the following packets:
* PlayerShoot
* PlayerHit
* EnemyHit
* Any other hits you may have (minions? static objects)

UNFINISHED.

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

## Explanations

