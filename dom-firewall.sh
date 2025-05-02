# Before running this script:
# ipset create dom_whitelist hash:ip hashsize 65536 maxelem 65536
# 
# Setup ipset to load when system starts:
# > netfilter-persistent reload
# Go to the path that this outputs, create 14-ipset file in that directory
# in that file write: 
# #!/bin/sh
# ipset restore < /etc/ipset.conf

# > chmod +x ./14-ipset
# > netfilter-persistent reload
# Check that now this command outputs 3 lines, where 14-ipset is the first one

#iptables -A INPUT -p tcp --dport 3389 -s <YOUR IP> -j ACCEPT # RDP
#iptables -A INPUT -p udp --dport 53 -j ACCEPT # DNS ... Possibly useless for a game server?
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp ! --syn -m conntrack --ctstate NEW -j DROP
iptables -A INPUT \
  -m recent --rcheck --seconds 60 --hitcount 1 --name dom_firewall_ban --rsource \
  -j DROP
iptables -A INPUT -p tcp --dport 6379 -s 127.0.0.1 -j ACCEPT

iptables -A INPUT -p tcp --dport 2050 \
  -m connlimit --connlimit-above 10 --connlimit-mask 32 \
  -j DROP
iptables -A INPUT -p tcp --dport 2051 \
  -m connlimit --connlimit-above 10 --connlimit-mask 32 \
  -j DROP
iptables -A INPUT -p tcp --dport 2052 \
  -m connlimit --connlimit-above 10 --connlimit-mask 32 \
  -j DROP
 
# Rate limit by packet size
#iptables -A INPUT -p tcp --dport 2050 -m length --length 1000:0xffff -m recent --name burstlist --set
#iptables -A INPUT -p tcp --dport 2051 -m length --length 1000:0xffff -m recent --name burstlist --set
#iptables -A INPUT -p tcp --dport 2052 -m length --length 1000:0xffff -m recent --name burstlist --set

#iptables -A INPUT -p tcp --dport 2050 -m recent --name burstlist --update --seconds 2 --hitcount 50 --rttl -j DROP
#iptables -A INPUT -p tcp --dport 2051 -m recent --name burstlist --update --seconds 2 --hitcount 50 --rttl -j DROP
#iptables -A INPUT -p tcp --dport 2052 -m recent --name burstlist --update --seconds 2 --hitcount 50 --rttl -j DROP

iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP 

iptables -N CHECK_LIMIT
iptables -A CHECK_LIMIT \
  -m hashlimit --hashlimit 2400/minute --hashlimit-burst 120 \
  --hashlimit-mode srcip --hashlimit-name post_accept_rate \
  -j RETURN
iptables -A CHECK_LIMIT -p tcp -m limit --limit 60/minute --limit-burst 60 -j LOG --log-prefix "CHECK Packet: "
iptables -A CHECK_LIMIT \
  -m recent --set --name dom_firewall_ban --rsource \
  -p tcp -j REJECT --reject-with tcp-reset

iptables -A INPUT -p tcp -m multiport --dports 2050,2051,2052 -j CHECK_LIMIT
iptables -A INPUT -p tcp --dport 2052 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 843 -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -p tcp -j ACCEPT
iptables -A INPUT -p tcp -m multiport --dports 2050,2051 -m set --match-set dom_whitelist src -j ACCEPT
iptables -P INPUT DROP
iptables -P FORWARD DROP

iptables -N SYN_LIMIT
iptables -A SYN_LIMIT -p tcp --syn -m hashlimit \
  --hashlimit 600/minute --hashlimit-burst 30 \
  --hashlimit-mode srcip --hashlimit-name synlimit \
  -j RETURN
iptables -A SYN_LIMIT -p tcp -m limit --limit 60/minute --limit-burst 60 -j LOG --log-prefix "SYN Packet: "
iptables -A SYN_LIMIT -p tcp --syn -j DROP
iptables -I INPUT 2 -p tcp --syn -j SYN_LIMIT 

iptables -N TCP_LIMIT
iptables -A TCP_LIMIT -p tcp -m hashlimit \
  --hashlimit 600/minute --hashlimit-burst 20 \
  --hashlimit-mode srcip --hashlimit-name tcplimit \
  -j RETURN
iptables -A TCP_LIMIT -p tcp -m limit --limit 60/minute --limit-burst 60 -j LOG --log-prefix "TCP Packet: "
iptables -A TCP_LIMIT -p tcp -j DROP
iptables -I INPUT 3 -p tcp -m multiport --dports 843,443,80,22 -j TCP_LIMIT

iptables -L -v -n --line-numbers | head -n 40

# USEFUL LOGGING COMMANDS

# Log incoming SYN packets (new connections), 
# -A appends it to the end so you see only those that fail to match any rule, replace with -I to see ALL ALL
# sudo iptables -A INPUT -p tcp --syn -j LOG --log-prefix "SYN Packet: "

# See incoming packets live:
# sudo journalctl -f -k | grep "SYN Packet"