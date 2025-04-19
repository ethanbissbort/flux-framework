#!/bin/bash

# Sysctl customizations


# create 99-fluxsysctl.conf if not exists
if [ ! -f /etc/sysctl.d/99-fluxsysctl.conf ]; then
    touch /etc/sysctl.d/99-fluxsysctl.conf
fi
# add sysctl hardening to 99-fluxsysctl.conf
# 


# The following is suitable for dedicated web server, mail, ftp server etc. 
# ---------------------------------------
# BOOLEAN Values:
# a) 0 (zero) - disabled / no / false
# b) Non zero - enabled / yes / true
# --------------------------------------
 
### Insert the correct tee command to put the new sysctl.conf into effect

sudo tee -a /etc/sysctl.d/99-fluxsysctl.conf > /dev/null << EOL

# Controls IP packet forwarding
net.ipv4.ip_forward = 0
 
# Do not accept source routing
net.ipv4.conf.default.accept_source_route = 0
 
# Controls the System Request debugging functionality of the kernel
kernel.sysrq = 0
 
# Controls whether core dumps will append the PID to the core filename
# Useful for debugging multi-threaded applications
kernel.core_uses_pid = 1
 
# Controls the use of TCP syncookies
# Turn on SYN-flood protections
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 5
 


########## IPv4 networking start ##############
# Send redirects, if router, but this is just server
# So no routing allowed 
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
 
# Accept packets with SRR option? No
net.ipv4.conf.all.accept_source_route = 0
 
# Accept Redirects? No, this is not router
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
 
# Log packets with impossible addresses to kernel log? yes
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
 
# Ignore all ICMP ECHO and TIMESTAMP requests sent to it via broadcast/multicast
net.ipv4.icmp_echo_ignore_broadcasts = 1
 
# Prevent against the common 'syn flood attack'
net.ipv4.tcp_syncookies = 1
 
# Enable source validation by reversed path, as specified in RFC1812
net.ipv4.conf.all.rp_filter = 1
 
# Controls source route verification
net.ipv4.conf.default.rp_filter = 1 
 
net.core.wmem_max = 12582912
net.core.rmem_max = 12582912
net.ipv4.tcp_rmem = 10240 87380 12582912
net.ipv4.tcp_wmem = 10240 87380 12582912
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_keepalive_intvl = 2
net.ipv4.tcp_keepalive_probes = 2
net.ipv4.tcp_keepalive_time = 1800


########## IPv6 networking start ##############
# Number of Router Solicitations to send until assuming no routers are present.
# This is host and not router
net.ipv6.conf.default.router_solicitations = 0
 
# Accept Router Preference in RA?
net.ipv6.conf.default.accept_ra_rtr_pref = 0
 
# Learn Prefix Information in Router Advertisement
net.ipv6.conf.default.accept_ra_pinfo = 0
 
# Setting controls whether the system will accept Hop Limit settings from a router advertisement
net.ipv6.conf.default.accept_ra_defrtr = 0
 
#router advertisements can cause the system to assign a global unicast address to an interface
net.ipv6.conf.default.autoconf = 0
 
#how many neighbor solicitations to send out per address?
net.ipv6.conf.default.dad_transmits = 0
 
# How many global unicast IPv6 addresses can be assigned to each interface?
net.ipv6.conf.default.max_addresses = 1
 
########## IPv6 networking ends ##############
 


#Enable ExecShield protection
#Set value to 1 or 2 (recommended) 
#kernel.exec-shield = 2
#kernel.randomize_va_space=2

 
# increase system file descriptor limit    
fs.file-max = 65535
 
#Allow for more PIDs 
kernel.pid_max = 65536
 
#Increase system IP port limits
net.ipv4.ip_local_port_range = 2000 65000
 
# RFC 1337 fix
net.ipv4.tcp_rfc1337=1



# BBR Congestion Control
net.core.default_qdisc=fq   
net.ipv4.tcp_congestion_control=bbr


# Reboot the machine soon after a kernel panic
kernel.panic=10

# Addresses of mmap base, heap, stack and VDSO page are randomized
kernel.randomize_va_space=2

#Ignore bad ICMP errors
net.ipv4.icmp_ignore_bogus_error_responses=1

# Protects against creating or following links under certain conditions
fs.protected_hardlinks=1
fs.protected_symlinks=1


# permanently apply 99-fluxsysctl.conf
sysctl -p /etc/sysctl.d/99-fluxsysctl.conf

EOL

echo "99-fluxsysctl.conf has been created and applied"
echo "Please reboot the system to apply the changes"
echo "Reboot now? (y/n)"
read answer
if [ "$answer" == "y" ]; then
    reboot
else
    echo "Please reboot the system to apply the changes"
fi
# End of script