#!/bin/bash

### This script is a template for creating a script that can be used to automate the setup of a new Linux system.
### It includes functions for handling various tasks such as changing the hostname, adding network interfaces, and more.


### Add trap to catch errors and cleanup

# Trap to catch errors and cleanup
trap 'echo "Error: $0:$LINENO stopped"; exit 1' ERR INT TERM
trap 'echo "Interrupted"; exit 1' INT
trap 'if [ $reboot_needed -eq 1 ]; then echo "Reboot needed"; else echo "No reboot needed"; fi' EXIT

### variable to keep track of reboot needed
reboot_needed=0

### Default network interface settings
default_netmask="255.255.0.0"
default_gateway="10.0.1.1"
default_dns_primary="10.0.1.101"
default_dns_secondary="8.8.8.8"
default_dns_domain="fluxlab.systems"
default_mtu="1500"
default_vlan_protocol="802.1Q"
default_vlan_flags="REORDER_HDR"
default_vlan_encapsulated_vlan="0"
default_vlan_encapsulated_protocol="802.1Q"
default_vlan_encapsulated_flags="REORDER_HDR"
default_vlan_encapsulated_encapsulation="dot1q"


# Function to display usage information
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h    Display this help message"
    echo "  -n    Change the hostname of the system"
    echo "  -i    Print network interfaces information"
    echo "  -a    Add a network interface"
    exit 1
}


# Function to change the hostname
change_hostname() {
    # shellcheck disable=SC2162
    read -p "Enter new FQDN (or leave blank to continue with hostname only): " new_fqdn
    if [ -n "$new_fqdn" ]; then
        sudo hostnamectl set-hostname "$new_fqdn" --static
        sudo hostnamectl set-hostname "$new_fqdn" --transient
        echo "FQDN changed to $new_fqdn"
        return
    fi
    # shellcheck disable=SC2162
    read -p "Enter new hostname: " new_hostname
    sudo hostnamectl set-hostname "$new_hostname"
    echo "Hostname changed to $new_hostname"
}

# Function to print network interfaces information
print_network_interfaces() {
    echo "Contents of /etc/network/interfaces:"
    cat /etc/network/interfaces
    echo ""
    echo "Network interfaces from lshw:"
    sudo lshw -class network -short
}

# Function to query network device paths and display NET_IDs
query_net_ids() {
    for net_dev in /sys/class/net/*; do
        dev_name=$(basename "$net_dev")
        if [ "$dev_name" != "lo" ]; then
            echo "Device: $dev_name"
            sudo udevadm info --query=all --path="$net_dev" | grep 'ID_NET_NAME'
            echo ""
        fi
    done
}


### Function to configure network interfaces with netplan
configure_netplan() {
    # Get the list of network interfaces
    echo "Available network interfaces:"
    ip link show
    echo ""

    # Ask the user for the network interface name
    read -p "Enter the network interface name (e.g., eth0): " interface_name

    # Ask the user for the IP address and subnet mask
    read -p "Enter the IP address and subnet mask (e.g., " ip_and_netmask
}


# Function to add a network interface
add_network_interface() {
    # shellcheck disable=SC2162
    read -p "Enter Ethernet connection name (? or ?? for list or ext list): " eth_name
    if [ "$eth_name" == "?" ]; then
        sudo lshw -class network -short
        # shellcheck disable=SC2162
        read -p "Enter Ethernet connection name: " eth_name
    fi
    if [ "$eth_name" == "??" ]; then
        sudo lshw -class network -short
        query_net_ids
        # shellcheck disable=SC2162
        read -p "Enter Ethernet connection name: " eth_name
    fi
    # shellcheck disable=SC2162
    read -p "Enter VLAN number (leave blank for none): " vlan_number
    # shellcheck disable=SC2162
    read -p "Enter Static IP address or blank for DHCP: " the_ip
    ### add logic to validate IP address
    while [[ ! -z "$the_ip" && ! "$the_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; do
        echo "Invalid IP address format."
        read -p "Enter Static IP address or blank for DHCP: " the_ip
    done


    # with DHCP
    if [ -z "$the_ip" ]; then 
    ### add logic to append vlan to eth_name if present (separate function to get extended vlan info?)
        sudo tee -a /etc/network/interfaces > /dev/null <<EOL
            auto $eth_name
            iface $eth_name inet dhcp
EOL
        echo "Network interface $eth_name added with DHCP."
        return ### We are leaving the function here because we are done with DHCP
    fi 
    # end with DHCP

    read -p "Enter netmask (leave blank for default - $default_netmask): " the_netmask
    read -p "Enter gateway (leave blank for default - $default_gateway): " the_gateway
    read -p "Enter primary DNS server (leave blank for default - $default_dns_primary): " the_dns_primary
    read -p "Enter secondary DNS server (leave blank for default - $default_dns_secondary): " the_dns_secondary
    read -p "Enter DNS domain (leave blank for default - $default_dns_domain): " the_dns_domain
    read -p "Enter MTU (leave blank for default $default_mtu): " the_mtu

    if [ -z "$the_netmask" ]; then
        the_netmask=$default_netmask
    fi
    if [ -z "$the_gateway" ]; then
        the_gateway=$default_gateway
    fi
    if [ -z "$the_dns_primary" ]; then
        the_dns_primary=$default_dns_primary
    fi
    if [ -z "$the_dns_secondary" ]; then
        the_dns_secondary=$default_dns_secondary
    fi
    if [ -z "$the_dns_domain" ]; then
        the_dns_domain=$default_dns_domain
    fi
    if [ -z "$the_mtu" ]; then
        the_mtu=$default_mtu
    fi



# without vlan
    if [ -z "$vlan_number" ]; then
    sudo tee -a /etc/network/interfaces > /dev/null <<EOL
        auto $eth_name
        iface $eth_name inet static
            address $the_ip
            netmask $the_netmask
            gateway $the_gateway
            dns-nameservers $the_dns_primary $the_dns_secondary
            dns-domain $the_dns_domain
            dns-register yes
            mtu $the_mtu
EOL
    echo "Network interface $eth_name added with static IP $the_ip."

# with vlan    
    else
    sudo tee -a /etc/network/interfaces > /dev/null <<EOL
        auto ${eth_name}.${vlan_number}
        iface ${eth_name}.${vlan_number} inet static
            address $the_ip
            netmask $the_netmask
            gateway $the_gateway
            dns-nameservers $the_dns_primary $the_dns_secondary
            dns-domain $the_dns_domain
            dns-register yes
            mtu $the_mtu
            vlan-raw-device $eth_name
            vlan-protocol $default_vlan_protocol
            vlan-id $vlan_number
            vlan-flags $default_vlan_flags
            vlan-encapsulated-vlan $default_vlan_encapsulated_vlan
            vlan-encapsulated-protocol $default_vlan_encapsulated_protocol
            vlan-encapsulated-flags $default_vlan_encapsulated_flags
            vlan-encapsulated-encapsulation $default_vlan_encapsulated_encapsulation

            echo "Configured VLAN ${vlan_number} on interface ${eth_name}" >> /var/log/network_interfaces.log
EOL
    echo "Network interface ${eth_name}.${vlan_number} added."

    echo "Network interface ${eth_name}.${vlan_number} configured successfully." >> /var/log/network_interfaces.log
    fi
}

# Function to add a user named fluxadmin and add to group
add_fluxadmin_user() {
    sudo useradd -m -s /bin/bash fluxadmin
    sudo usermod -aG fluxadmin fluxadmin
    sudo passwd fluxadmin
    echo "User fluxadmin added and added to group."
}



### zsh and omz function
# install zsh
# install oh-my-zsh
# set zsh as default shell
    # if running as root, then do not change root shell
    # if running as user, then change shell
# get .zshrc file and theme from repo


### Custom MOTD function
### configure ASCII art
# backup existing motd
# get ASCII art from repo
# set ASCII art to /etc/motd
# get additional motd from repo
# set motd to new motd
# restart sshd


### initial update and upgrade func


### Add trusted/root CAs
# get trusted CAs from repo
# add to /usr/local/share/ca-certificates
# update-ca-certificates


### Add to NetData
# get netdata installer from repo
# run installer
# use following token: 1234567890abcdef1234567890abcdef

### set system locale and timezone
# Function to set system locale and timezone
set_locale_and_timezone() {
    # Set system locale to en_US.UTF-8
    sudo locale-gen en_US.UTF-8
    sudo update-locale LANG=en_US.UTF-8

    # Set timezone to America/New_York
    sudo timedatectl set-timezone America/New_York

    # Restart services to apply changes
    sudo systemctl restart rsyslog
    sudo systemctl restart cron
    sudo systemctl restart atd
    sudo systemctl restart systemd-timedated

    echo "Locale set to en_US.UTF-8 and timezone set to America/New_York."
}

### ssh hardening
ssh_hardening() {
    # Backup sshd_config
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    # Import SSH key from a GitHub user
    read -p "Enter the GitHub username to import SSH key from: " github_user
    curl -s "https://github.com/${github_user}.keys" >> ~/.ssh/authorized_keys
    echo "SSH key(s) from GitHub user ${github_user} added to authorized keys."


    # Get SSH key from repo and add to authorized keys
    # shellcheck disable=SC2162
    read -p "Enter the URL of the SSH key to add: " ssh_key_url
    curl -o /tmp/temp_ssh_key "$ssh_key_url"
    cat /tmp/temp_ssh_key >> ~/.ssh/authorized_keys
    rm /tmp/temp_ssh_key

    # Change SSH port to 2202
    sudo sed -i 's/#Port 22/Port 2202/' /etc/ssh/sshd_config

    # Disable root login
    sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

    # Disable password authentication
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config


    # Re-generate the ED25519 and RSA keys
    sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
    sudo ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ""
    # Remove small Diffie-Hellman moduli
    sudo cp /etc/ssh/moduli /etc/ssh/moduli.bak
    sudo awk '$5 >= 3071' /etc/ssh/moduli > /etc/ssh/moduli.safe
    sudo mv /etc/ssh/moduli.safe /etc/ssh/moduli
    # Enable the ED25519 and RSA keys
    echo -e "\nHostKey /etc/ssh/ssh_host_ed25519_key\nHostKey /etc/ssh/ssh_host_rsa_key" | sudo tee -a /etc/ssh/sshd_config
    # Restrict supported key exchange, cipher, and MAC algorithms
    echo -e "# Restrict key exchange, cipher, and MAC algorithms, as per sshaudit.com\n# hardening guide.\nKexAlgorithms sntrup761x25519-sha512@openssh.com,gss-curve25519-sha256-,curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256,gss-group16-sha512-,diffie-hellman-group16-sha512\n\nCiphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-gcm@openssh.com,aes128-ctr\n\nMACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com\n\nRequiredRSASize 3072\n\nHostKeyAlgorithms sk-ssh-ed25519-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256\n\nCASignatureAlgorithms sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256\n\nGSSAPIKexAlgorithms gss-curve25519-sha256-,gss-group16-sha512-\n\nHostbasedAcceptedAlgorithms sk-ssh-ed25519-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256\n\nPubkeyAcceptedAlgorithms sk-ssh-ed25519-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256" | sudo tee /etc/ssh/sshd_config.d/ssh-audit_hardening.conf
    # Restart SSH service to apply changes
    sudo systemctl restart sshd

    echo "SSH hardening applied successfully."
}

### custom sysctl implementation
# backup sysctl.conf
# curl or wget the flux-sysctl.sh file from the repo, chmod +x the file, run the file
# curl -o flux-sysctl.sh https://raw.githubusercontent.com/ethanbissbort/nix-init/main/flux-sysctl.sh
# chmod +x flux-sysctl.sh
# ./flux-sysctl.sh




### Parse command line options
while getopts "ahni" opt; do
    case ${opt} in

        n)
            change_hostname
            ;;
        i)
            print_network_interfaces
            ;;
        h)
            usage
            ;;
        a)
            add_network_interface
            ;;
        *)
            usage
            ;;
    esac
done

# If no options were passed, display usage
if [ $OPTIND -eq 1 ]; then
    usage
fi
