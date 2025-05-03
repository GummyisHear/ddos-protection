# Create an ipset which can hold maximum of 65536 IPs
sudo ipset create dom_whitelist hash:ip hashsize 65536 maxelem 65536

# Add IPs to it
sudo ipset add dom_whitelist <IP_ADDRESS>

# Save the ipset to a file
sudo ipset save > /etc/ipset.conf

# Then you want to remove any rules allowing ports 2050/2051, and replace them with this: 
sudo iptables -A INPUT -p tcp -m multiport --dports 2050,2051 -m set --match-set dom_whitelist src -j ACCEPT

# Now only IPs which are in the ipset can connect to ports 2050, 2051
# Make sure the order of your rules makes sense

# To restore an ipset, use:
sudo ipset restore < /etc/ipset.conf


# ipsets are not saved when system restarts, and are not restored. 
# You have to do that yourself, or make use of netfilter-persistent to do it automatically.

netfilter-persistent reload
# Go to the path that this outputs, create 14-ipset file in that directory
# in that file write: 
#!/bin/sh
ipset restore < /etc/ipset.conf

# Save the file and do this:
sudo chmod +x ./14-ipset
sudo netfilter-persistent reload
# Check that now this command outputs 3 lines, where 14-ipset is the first one