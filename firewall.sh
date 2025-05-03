# Ports 2050, 2051 are wServer and appEngine respectively, change those to your servers ports.

#iptables -A INPUT -p tcp --dport 3389 -s <YOUR IP> -j ACCEPT # RDP
#iptables -A INPUT -p udp --dport 53 -j ACCEPT # DNS ... Possibly useless for a game server?
iptables -A INPUT -i lo -j ACCEPT  # Accept all Localhost incoming packets
iptables -A INPUT -p tcp --dport 22 -j ACCEPT  # Accept SSH Port packets
iptables -A INPUT -p tcp ! --syn -m conntrack --ctstate NEW -j DROP # Drop spoofed SYN packets, SYN spam protection
iptables -A INPUT \ # 1 minute ban for triggering Rate-Limit
  -m recent --rcheck --seconds 60 --hitcount 1 --name dom_firewall_ban --rsource \
  -j DROP
iptables -A INPUT -p tcp --dport 6379 -s 127.0.0.1 -j ACCEPT # Accept Redis port

iptables -A INPUT -p tcp --dport 2050 \ # wServer port, limit to max of 10 simultaneous connections per ip
  -m connlimit --connlimit-above 10 --connlimit-mask 32 \
  -j DROP
iptables -A INPUT -p tcp --dport 2051 \ # appEngine port, limit to max of 10 simultaneous connections per ip
  -m connlimit --connlimit-above 10 --connlimit-mask 32 \
  -j DROP
 
# Rate limit by packet size
# Learn about packet fragmentation and your server's packet sizes if you want to use this
#iptables -A INPUT -p tcp --dport 2050 -m length --length 1000:0xffff -m recent --name burstlist --set
#iptables -A INPUT -p tcp --dport 2051 -m length --length 1000:0xffff -m recent --name burstlist --set

#iptables -A INPUT -p tcp --dport 2050 -m recent --name burstlist --update --seconds 2 --hitcount 50 --rttl -j DROP
#iptables -A INPUT -p tcp --dport 2051 -m recent --name burstlist --update --seconds 2 --hitcount 50 --rttl -j DROP

# Drop broken packets which are marked invalid by kernel
iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP 

# Rate-limit chain for ports 2050, 2051
iptables -N CHECK_LIMIT
iptables -A CHECK_LIMIT \ # max 40 packets/sec, burst value of 120, if packet count is below the limit this rule is triggered, if above, it goes further in this chain
  -m hashlimit --hashlimit 2400/minute --hashlimit-burst 120 \
  --hashlimit-mode srcip --hashlimit-name post_accept_rate \
  -j RETURN
iptables -A CHECK_LIMIT -p tcp -m limit --limit 5/minute --limit-burst 10 -j LOG --log-prefix "CHECK Packet: " # just a log
iptables -A CHECK_LIMIT \ # add ip to dom_firewall_ban, and send connection reset
  -m recent --set --name dom_firewall_ban --rsource \
  -p tcp -j REJECT --reject-with tcp-reset

iptables -A INPUT -p tcp -m multiport --dports 2050,2051 -j CHECK_LIMIT # make all packets on ports 2050, 2051 go through the rate-limit chain
iptables -A INPUT -p tcp --dport 2050 -j ACCEPT # accept wServer packets
iptables -A INPUT -p tcp --dport 2051 -j ACCEPT # accept appEngine packets
iptables -A INPUT -p tcp --dport 443 -j ACCEPT # accept standard HTTPS port
iptables -A INPUT -p tcp --dport 843 -j ACCEPT # accept Flash's Policy File port
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -p tcp -j ACCEPT # accept packets which are related to established connections
iptables -P INPUT DROP # default rule, drop all packets
iptables -P FORWARD DROP # we are not a router, drop all packets

# Rate-limit chain for new connections (further syn spam protection)
iptables -N SYN_LIMIT 
iptables -A SYN_LIMIT -p tcp --syn -m hashlimit \
  --hashlimit 600/minute --hashlimit-burst 30 \
  --hashlimit-mode srcip --hashlimit-name synlimit \
  -j RETURN
iptables -A SYN_LIMIT -p tcp -m limit --limit 5/minute --limit-burst 10 -j LOG --log-prefix "SYN Packet: "
iptables -A SYN_LIMIT -p tcp --syn -j DROP
iptables -I INPUT 2 -p tcp --syn -j SYN_LIMIT 

# Rate-limit chain for every other port we have open, more strict rate-limiting than ports 2050, 2051
# This also rate-limits the ssh port, and you can feel ssh being a bit buggy when you type too fast, can remove it by removign port 22
iptables -N TCP_LIMIT
iptables -A TCP_LIMIT -p tcp -m hashlimit \
  --hashlimit 600/minute --hashlimit-burst 20 \
  --hashlimit-mode srcip --hashlimit-name tcplimit \
  -j RETURN
iptables -A TCP_LIMIT -p tcp -m limit --limit 5/minute --limit-burst 10 -j LOG --log-prefix "TCP Packet: "
iptables -A TCP_LIMIT -p tcp -j DROP
iptables -I INPUT 3 -p tcp -m multiport --dports 843,443,22 -j TCP_LIMIT

iptables -L -v -n --line-numbers | head -n 40 # print first 40 rules in iptables

# CLEANING IPTABLES

# DO THIS FIRST!!!
# iptables -P INPUT ACCEPT

# Then this...
# iptables -F
# iptables -X

# USEFUL LOGGING COMMANDS

# Log incoming SYN packets (new connections), 
# -A appends it to the end so you see only those that fail to match any rule, replace with -I to see ALL ALL
# sudo iptables -A INPUT -p tcp --syn -j LOG --log-prefix "SYN Packet: "

# See incoming packets live:
# sudo journalctl -f -k | grep "SYN Packet"
