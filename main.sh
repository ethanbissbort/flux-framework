#!/bin/bash



# Function to display usage information
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -a    Description for option a"
    echo "  -b    Description for option b"
    echo "  -c    Description for option c"
    echo "  -h    Display this help message"
    echo "  -n    Change the hostname of the system"
    echo "  -i    Print network interfaces information"
    echo "  -d    Add a network interface"
    exit 1
}

# Function to handle option a
option_a() {
    echo "Option a selected"
    # Add your code here
}

# Function to handle option b
option_b() {
    echo "Option b selected"
    # Add your code here
}

# Function to handle option c
option_c() {
    echo "Option c selected"
    # Add your code here
}

# Function to change the hostname
change_hostname() {
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

# Function to add a network interface
add_network_interface() {
    read -p "Enter Ethernet connection name: " eth_name
    read -p "Enter VLAN number: " vlan_number
    sudo tee -a /etc/network/interfaces > /dev/null <<EOL

auto ${eth_name}.${vlan_number}
iface ${eth_name}.${vlan_number} inet static
    address 192.168.1.1
    netmask 255.255.0.0
    vlan-raw-device ${eth_name}
EOL
    echo "Network interface ${eth_name}.${vlan_number} added."
}

# Function to add a user named fluxadmin and add to sudo group
add_fluxadmin_user() {
    sudo useradd -m -s /bin/bash fluxadmin
    sudo usermod -aG sudo fluxadmin
    sudo passwd fluxadmin
    echo "User fluxadmin added and added to sudo group."
}






# zsh and omz function

# initial update and upgrade func

# ssh hardening
# backup sshd_config
# get ssh key from repo and add to authorized keys
# change ssh port to 2202
# disable root login
# disable password authentication
# Re-generate the ED25519 and RSA keys
ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ""
# Remove small Diffie-Hellman moduli
awk '$5 >= 3071' /etc/ssh/moduli > /etc/ssh/moduli.safe
mv /etc/ssh/moduli.safe /etc/ssh/moduli
# Enable the ED25519 and RSA keys
echo -e "\nHostKey /etc/ssh/ssh_host_ed25519_key\nHostKey /etc/ssh/ssh_host_rsa_key" >> /etc/ssh/sshd_config
# Restrict supported key exchange, cipher, and MAC algorithms
echo -e "# Restrict key exchange, cipher, and MAC algorithms, as per sshaudit.com\n# hardening guide.\nKexAlgorithms sntrup761x25519-sha512@openssh.com,gss-curve25519-sha256-,curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256,gss-group16-sha512-,diffie-hellman-group16-sha512\n\nCiphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-gcm@openssh.com,aes128-ctr\n\nMACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com\n\nRequiredRSASize 3072\n\nHostKeyAlgorithms sk-ssh-ed25519-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256\n\nCASignatureAlgorithms sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256\n\nGSSAPIKexAlgorithms gss-curve25519-sha256-,gss-group16-sha512-\n\nHostbasedAcceptedAlgorithms sk-ssh-ed25519-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256\n\nPubkeyAcceptedAlgorithms sk-ssh-ed25519-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,ssh-ed25519,rsa-sha2-512,rsa-sha2-256" > /etc/ssh/sshd_config.d/ssh-audit_hardening.conf
# restart sshd


# Parse command line options
while getopts "abchnid" opt; do
    case ${opt} in
        a)
            option_a
            ;;
        b)
            option_b
            ;;
        c)
            option_c
            ;;
        n)
            change_hostname
            ;;
        i)
            print_network_interfaces
            ;;
        h)
            usage
            ;;
        d)
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