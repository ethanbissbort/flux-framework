#!/bin/bash

# main.sh - Flux system setup script with integrated modules
# Complete system administration and configuration framework

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/flux-helpers.sh" ]]; then
    source "$SCRIPT_DIR/flux-helpers.sh"
else
    echo "Error: flux-helpers.sh not found in $SCRIPT_DIR"
    echo "Please ensure all Flux modules are in the same directory"
    exit 1
fi

# Set up error handling
setup_error_handling

# =============================================================================
# CONFIGURATION & DEFAULTS
# =============================================================================

# Version information
readonly FLUX_VERSION="2.0.0"
readonly FLUX_RELEASE="2025.05"

# Available modules
readonly AVAILABLE_MODULES=(
    "flux-update.sh"
    "flux-certs.sh" 
    "flux-sysctl.sh"
    "flux-zsh.sh"
    "flux-motd.sh"
    "flux-netdata.sh"
)

# Default network interface settings (backward compatibility)
readonly DEFAULT_NETMASK="255.255.0.0"
readonly DEFAULT_GATEWAY="10.0.1.1"
readonly DEFAULT_DNS_PRIMARY="10.0.1.101"
readonly DEFAULT_DNS_SECONDARY="8.8.8.8"
readonly DEFAULT_DNS_DOMAIN="fluxlab.systems"
readonly DEFAULT_MTU="1500"

# =============================================================================
# MODULE INTEGRATION FUNCTIONS
# =============================================================================

# Check if all required modules are present
check_modules() {
    log_info "Checking for required Flux modules"
    
    local missing_modules=()
    
    for module in "${AVAILABLE_MODULES[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$module" ]]; then
            missing_modules+=("$module")
        fi
    done
    
    if [[ ${#missing_modules[@]} -gt 0 ]]; then
        log_warn "Missing modules: ${missing_modules[*]}"
        echo -e "${YELLOW}Some features may not be available.${NC}"
        
        if prompt_yes_no "Continue anyway?" "y"; then
            return 0
        else
            log_error "Cannot proceed without required modules"
            return 1
        fi
    fi
    
    log_info "All required modules found"
    return 0
}

# Execute module with error handling
execute_module() {
    local module_script="$1"
    shift
    local module_args="$@"
    
    local module_path="$SCRIPT_DIR/$module_script"
    
    if [[ ! -f "$module_path" ]]; then
        log_error "Module not found: $module_script"
        return 1
    fi
    
    if [[ ! -x "$module_path" ]]; then
        chmod +x "$module_path"
    fi
    
    log_info "Executing module: $module_script $module_args"
    
    if "$module_path" $module_args; then
        log_info "Module $module_script completed successfully"
        return 0
    else
        log_error "Module $module_script failed"
        return 1
    fi
}

# =============================================================================
# SYSTEM SETUP FUNCTIONS (Enhanced with modules)
# =============================================================================

# System update and upgrade using dedicated module
initial_update_upgrade() {
    log_info "Starting system update and upgrade"
    
    local include_dev=false
    local enable_auto_updates=false
    
    if prompt_yes_no "Include development packages?" "n"; then
        include_dev=true
    fi
    
    if prompt_yes_no "Configure automatic security updates?" "y"; then
        enable_auto_updates=true
    fi
    
    local args=("-f")
    if [[ "$include_dev" == true ]]; then
        args+=("-d")
    fi
    if [[ "$enable_auto_updates" == true ]]; then
        args+=("-a")
    fi
    
    if execute_module "flux-update.sh" "${args[@]}"; then
        log_info "System update completed successfully"
        return 0
    else
        log_error "System update failed"
        return 1
    fi
}

# Install certificates using dedicated module
install_certificates() {
    log_info "Installing certificates"
    
    local repo_url=""
    read -p "Enter certificate repository URL (or press Enter for default): " repo_url
    
    local args=()
    if [[ -n "$repo_url" ]]; then
        args+=("$repo_url")
    fi
    
    if execute_module "flux-certs.sh" "${args[@]}"; then
        log_info "Certificate installation completed"
        return 0
    else
        log_error "Certificate installation failed"
        return 1
    fi
}

# Apply sysctl hardening using dedicated module
apply_sysctl_hardening() {
    log_info "Applying sysctl hardening"
    
    if execute_module "flux-sysctl.sh"; then
        set_reboot_needed "Sysctl parameters modified"
        log_info "Sysctl hardening completed"
        return 0
    else
        log_error "Sysctl hardening failed"
        return 1
    fi
}

# Install ZSH and Oh-My-Zsh using dedicated module
install_zsh_omz() {
    log_info "Installing ZSH and Oh-My-Zsh"
    
    local theme="default"
    local custom_config=""
    local set_default=true
    
    echo -e "${CYAN}ZSH Theme Options:${NC}"
    echo "  1) robbyrussell (default)"
    echo "  2) agnoster"
    echo "  3) powerlevel10k"
    echo "  4) custom"
    
    read -p "Select theme (1-4) [1]: " theme_choice
    
    case "$theme_choice" in
        2) theme="agnoster" ;;
        3) theme="powerlevel10k" ;;
        4) 
            read -p "Enter theme name: " theme
            read -p "Enter custom .zshrc URL (optional): " custom_config
            ;;
        *) theme="robbyrussell" ;;
    esac
    
    if ! prompt_yes_no "Set ZSH as default shell?" "y"; then
        set_default=false
    fi
    
    local args=()
    if [[ "$theme" == "powerlevel10k" ]]; then
        args+=("-p")
    elif [[ "$theme" != "robbyrussell" ]]; then
        args+=("-t" "$theme")
    fi
    
    if [[ -n "$custom_config" ]]; then
        args+=("-c" "$custom_config")
    fi
    
    if [[ "$set_default" == false ]]; then
        args+=("-n")
    fi
    
    if execute_module "flux-zsh.sh" "${args[@]}"; then
        log_info "ZSH installation completed"
        return 0
    else
        log_error "ZSH installation failed"
        return 1
    fi
}

# Setup custom MOTD using dedicated module
setup_custom_motd() {
    log_info "Setting up custom MOTD"
    
    local ascii_art="default"
    local color="cyan"
    local organization=""
    local message=""
    local enable_security=true
    local enable_logins=false
    local ssh_banner=false
    
    echo -e "${CYAN}ASCII Art Options:${NC}"
    echo "  1) default - Standard Flux logo"
    echo "  2) flux-large - Large Flux Lab logo"
    echo "  3) simple - Simple text banner"
    echo "  4) minimal - Minimal box design"
    echo "  5) custom - Enter URL or file path"
    
    read -p "Select ASCII art (1-5) [1]: " art_choice
    
    case "$art_choice" in
        2) ascii_art="flux-large" ;;
        3) ascii_art="simple" ;;
        4) ascii_art="minimal" ;;
        5) 
            read -p "Enter URL or file path: " ascii_art
            ;;
        *) ascii_art="default" ;;
    esac
    
    echo -e "${CYAN}Color Options:${NC}"
    echo "  1) cyan (default)  2) blue  3) green  4) purple  5) red  6) yellow  7) white"
    read -p "Select color (1-7) [1]: " color_choice
    
    case "$color_choice" in
        2) color="blue" ;;
        3) color="green" ;;
        4) color="purple" ;;
        5) color="red" ;;
        6) color="yellow" ;;
        7) color="white" ;;
        *) color="cyan" ;;
    esac
    
    read -p "Enter organization name (optional): " organization
    read -p "Enter custom welcome message (optional): " message
    
    if prompt_yes_no "Include login information?" "n"; then
        enable_logins=true
    fi
    
    if prompt_yes_no "Create SSH login banner?" "n"; then
        ssh_banner=true
    fi
    
    local args=("-a" "$ascii_art" "-c" "$color")
    
    if [[ -n "$organization" ]]; then
        args+=("-o" "$organization")
    fi
    
    if [[ -n "$message" ]]; then
        args+=("-m" "$message")
    fi
    
    if [[ "$enable_logins" == true ]]; then
        args+=("--logins")
    fi
    
    if [[ "$ssh_banner" == true ]]; then
        args+=("--ssh-banner")
    fi
    
    if execute_module "flux-motd.sh" "${args[@]}"; then
        log_info "MOTD setup completed"
        return 0
    else
        log_error "MOTD setup failed"
        return 1
    fi
}

# Setup NetData monitoring using dedicated module
setup_netdata() {
    log_info "Setting up NetData monitoring"
    
    local claim_token=""
    local enable_ssl=false
    local allow_external=false
    local allowed_ips=""
    local notification_method="email"
    
    read -p "Enter NetData Cloud claim token (optional): " claim_token
    
    if prompt_yes_no "Enable SSL/TLS?" "n"; then
        enable_ssl=true
    fi
    
    if prompt_yes_no "Allow external access?" "n"; then
        allow_external=true
        
        if prompt_yes_no "Restrict to specific IP addresses?" "y"; then
            read -p "Enter allowed IPs (comma-separated): " allowed_ips
        fi
    fi
    
    echo -e "${CYAN}Notification Options:${NC}"
    echo "  1) email (default)  2) discord  3) slack"
    read -p "Select notification method (1-3) [1]: " notif_choice
    
    case "$notif_choice" in
        2) notification_method="discord" ;;
        3) notification_method="slack" ;;
        *) notification_method="email" ;;
    esac
    
    local args=()
    
    if [[ -n "$claim_token" ]]; then
        args+=("-c" "$claim_token")
    fi
    
    if [[ "$enable_ssl" == true ]]; then
        args+=("-s")
    fi
    
    if [[ "$allow_external" == true ]]; then
        args+=("-e")
        
        if [[ -n "$allowed_ips" ]]; then
            args+=("--allowed-ips" "$allowed_ips")
        fi
    fi
    
    if [[ "$notification_method" != "email" ]]; then
        args+=("--notification" "$notification_method")
    fi
    
    if execute_module "flux-netdata.sh" "${args[@]}"; then
        log_info "NetData setup completed"
        return 0
    else
        log_error "NetData setup failed"
        return 1
    fi
}

# =============================================================================
# LEGACY FUNCTIONS (kept for backward compatibility)
# =============================================================================

# Change hostname (enhanced version)
change_hostname() {
    log_info "Starting hostname configuration"
    
    local new_fqdn
    local new_hostname
    
    echo -e "${CYAN}Current hostname: $(hostname)${NC}"
    echo -e "${CYAN}Current FQDN: $(hostname -f 2>/dev/null || echo 'Not set')${NC}"
    echo
    
    new_fqdn=$(prompt_hostname "Enter new FQDN (Fully Qualified Domain Name)" "")
    
    if [[ -n "$new_fqdn" ]]; then
        backup_file "/etc/hostname"
        backup_file "/etc/hosts"
        
        sudo hostnamectl set-hostname "$new_fqdn" --static
        sudo hostnamectl set-hostname "$new_fqdn" --transient
        
        # Update /etc/hosts
        local ip_addr=$(hostname -I | awk '{print $1}')
        echo "127.0.0.1 localhost" | sudo tee /etc/hosts > /dev/null
        echo "$ip_addr $new_fqdn $(echo "$new_fqdn" | cut -d. -f1)" | sudo tee -a /etc/hosts > /dev/null
        
        log_info "FQDN changed to $new_fqdn"
        return 0
    fi
    
    new_hostname=$(prompt_hostname "Enter new hostname")
    
    if [[ -n "$new_hostname" ]]; then
        backup_file "/etc/hostname"
        sudo hostnamectl set-hostname "$new_hostname"
        log_info "Hostname changed to $new_hostname"
    fi
}

# Print network interfaces information
print_network_interfaces() {
    log_info "Displaying network interface information"
    
    echo -e "${CYAN}=== Network Interfaces Configuration ===${NC}"
    if [[ -f /etc/network/interfaces ]]; then
        echo -e "${WHITE}Contents of /etc/network/interfaces:${NC}"
        cat /etc/network/interfaces
    else
        echo -e "${YELLOW}/etc/network/interfaces not found (system may use netplan)${NC}"
    fi
    
    echo -e "\n${WHITE}Hardware network interfaces:${NC}"
    if command -v lshw >/dev/null 2>&1; then
        sudo lshw -class network -short 2>/dev/null || ip link show
    else
        ip link show
    fi
    
    echo -e "\n${WHITE}Current IP configuration:${NC}"
    ip addr show | grep -E "(inet |link/ether)" | sed 's/^/  /'
}

# Add network interface (enhanced version)
add_network_interface() {
    log_info "Starting network interface configuration"
    
    local eth_name
    local vlan_number
    local ip_address
    local netmask
    local gateway
    local dns_primary
    local dns_secondary
    local dns_domain
    local mtu
    
    # Get interface name
    eth_name=$(prompt_interface "Enter network interface name")
    
    # Get VLAN number (optional)
    read -p "Enter VLAN number (1-4094, or press Enter for none): " vlan_number
    if [[ -n "$vlan_number" ]]; then
        if ! validate_vlan "$vlan_number"; then
            log_error "Invalid VLAN number: $vlan_number"
            return 1
        fi
        
        if ! interface_supports_vlan "$eth_name"; then
            log_error "Interface $eth_name does not support VLANs or VLAN module unavailable"
            return 1
        fi
    fi
    
    # Get IP configuration
    ip_address=$(prompt_with_validation "Enter Static IP address (or press Enter for DHCP)" "" "" "")
    
    # Backup interfaces file
    backup_file "/etc/network/interfaces"
    
    # Configure interface
    local interface_name="$eth_name"
    if [[ -n "$vlan_number" ]]; then
        interface_name="${eth_name}.${vlan_number}"
    fi
    
    # DHCP configuration
    if [[ -z "$ip_address" ]]; then
        local config="
auto $interface_name
iface $interface_name inet dhcp"
        
        if [[ -n "$vlan_number" ]]; then
            config="$config
    vlan-raw-device $eth_name"
        fi
        
        safe_append_file "/etc/network/interfaces" "$config"
        log_info "Network interface $interface_name configured with DHCP"
        return 0
    fi
    
    # Static IP configuration
    netmask=$(prompt_ip "Enter netmask" "$DEFAULT_NETMASK")
    gateway=$(prompt_ip "Enter gateway" "$DEFAULT_GATEWAY")
    dns_primary=$(prompt_ip "Enter primary DNS server" "$DEFAULT_DNS_PRIMARY")
    dns_secondary=$(prompt_ip "Enter secondary DNS server" "$DEFAULT_DNS_SECONDARY")
    
    read -p "Enter DNS domain [default: $DEFAULT_DNS_DOMAIN]: " dns_domain
    dns_domain=${dns_domain:-$DEFAULT_DNS_DOMAIN}
    
    read -p "Enter MTU [default: $DEFAULT_MTU]: " mtu
    mtu=${mtu:-$DEFAULT_MTU}
    
    # Build configuration
    local config="
auto $interface_name
iface $interface_name inet static
    address $ip_address
    netmask $netmask
    gateway $gateway
    dns-nameservers $dns_primary $dns_secondary
    dns-domain $dns_domain
    dns-register yes
    mtu $mtu"
    
    # Add VLAN configuration if needed
    if [[ -n "$vlan_number" ]]; then
        config="$config
    vlan-raw-device $eth_name
    vlan-protocol 802.1Q
    vlan-id $vlan_number
    vlan-flags REORDER_HDR"
    fi
    
    # Write configuration
    safe_append_file "/etc/network/interfaces" "$config"
    
    # Log the configuration
    echo "$(date): Configured interface $interface_name with IP $ip_address" >> /var/log/network_interfaces.log
    
    log_info "Network interface $interface_name configured successfully with static IP $ip_address"
    
    # Ask if user wants to bring up the interface
    if prompt_yes_no "Bring up the interface now?" "y"; then
        if sudo ifup "$interface_name" 2>/dev/null; then
            log_info "Interface $interface_name brought up successfully"
        else
            log_warn "Failed to bring up interface $interface_name. You may need to reboot or manually configure."
        fi
    fi
}

# Add user (enhanced)
add_fluxadmin_user() {
    log_info "Adding fluxadmin user"
    
    # Check if user already exists
    if id "fluxadmin" >/dev/null 2>&1; then
        log_warn "User fluxadmin already exists"
        if prompt_yes_no "Reconfigure existing user?" "n"; then
            sudo usermod -aG sudo fluxadmin
            log_info "User fluxadmin reconfigured"
        fi
        return 0
    fi
    
    # Create user
    if sudo useradd -m -s /bin/bash fluxadmin; then
        log_info "User fluxadmin created successfully"
    else
        log_error "Failed to create user fluxadmin"
        return 1
    fi
    
    # Add to sudo group
    if sudo usermod -aG sudo fluxadmin; then
        log_info "User fluxadmin added to sudo group"
    else
        log_warn "Failed to add fluxadmin to sudo group"
    fi
    
    # Set password
    echo -e "${YELLOW}Setting password for fluxadmin user:${NC}"
    if sudo passwd fluxadmin; then
        log_info "Password set for fluxadmin user"
    else
        log_error "Failed to set password for fluxadmin user"
        return 1
    fi
    
    # Setup SSH directory
    sudo mkdir -p /home/fluxadmin/.ssh
    sudo chown fluxadmin:fluxadmin /home/fluxadmin/.ssh
    sudo chmod 700 /home/fluxadmin/.ssh
    
    log_info "User fluxadmin configured successfully"
}

# SSH hardening (enhanced)
ssh_hardening() {
    log_info "Starting SSH hardening configuration"
    
    # Backup SSH configuration
    backup_file "/etc/ssh/sshd_config"
    
    # Get GitHub username for SSH key import
    local github_user
    read -p "Enter GitHub username to import SSH keys from (or press Enter to skip): " github_user
    
    if [[ -n "$github_user" ]]; then
        log_info "Importing SSH keys from GitHub user: $github_user"
        
        # Create .ssh directory with proper permissions
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        
        # Download and validate SSH keys
        local temp_keys="/tmp/github_keys.$"
        if safe_download "https://github.com/${github_user}.keys" "$temp_keys"; then
            if grep -E '^ssh-' "$temp_keys" > /tmp/valid_keys.$; then
                cat /tmp/valid_keys.$ >> ~/.ssh/authorized_keys
                chmod 600 ~/.ssh/authorized_keys
                log_info "SSH keys from GitHub user $github_user added successfully"
                rm -f /tmp/valid_keys.$
            else
                log_warn "No valid SSH keys found for GitHub user $github_user"
            fi
            rm -f "$temp_keys"
        else
            log_error "Failed to download SSH keys for GitHub user $github_user"
        fi
    fi
    
    # SSH port configuration
    local ssh_port
    ssh_port=$(prompt_with_validation "Enter SSH port" "validate_port" "2202" "Invalid port number (1-65535)")
    
    # Apply SSH hardening
    sudo sed -i "s/#Port 22/Port $ssh_port/" /etc/ssh/sshd_config
    sudo sed -i "s/Port 22/Port $ssh_port/" /etc/ssh/sshd_config
    sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    
    # Regenerate host keys
    log_info "Regenerating SSH host keys"
    sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" -q
    sudo ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N "" -q
    
    # Apply hardening configuration
    local hardening_config="/etc/ssh/sshd_config.d/ssh-audit_hardening.conf"
    cat > /tmp/ssh_hardening.conf << 'EOF'
# SSH Hardening Configuration - Generated by Flux

# Host Keys
HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

# Key Exchange Algorithms
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group18-sha512,diffie-hellman-group-exchange-sha256,diffie-hellman-group16-sha512

# Ciphers
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-gcm@openssh.com,aes128-ctr

# MACs
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com

# Security settings
RequiredRSASize 3072
MaxAuthTries 3
MaxSessions 4
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
    
    sudo mv /tmp/ssh_hardening.conf "$hardening_config"
    
    # Test and restart SSH
    if sudo sshd -t; then
        log_info "SSH configuration syntax is valid"
        if sudo systemctl restart sshd; then
            log_info "SSH service restarted successfully"
            echo -e "${GREEN}SSH hardening completed successfully!${NC}"
            echo -e "${YELLOW}IMPORTANT: SSH is now configured on port $ssh_port${NC}"
            echo -e "${YELLOW}Make sure you can connect before closing this session!${NC}"
        else
            log_error "Failed to restart SSH service"
            return 1
        fi
    else
        log_error "SSH configuration has syntax errors"
        return 1
    fi
}

# Set locale and timezone (enhanced)
set_locale_and_timezone() {
    log_info "Setting system locale and timezone"
    
    # Set locale
    log_info "Generating en_US.UTF-8 locale"
    sudo locale-gen en_US.UTF-8
    sudo update-locale LANG=en_US.UTF-8
    
    # Set timezone
    log_info "Setting timezone to America/New_York"
    sudo timedatectl set-timezone America/New_York
    
    # Restart relevant services
    local services=("rsyslog" "cron" "atd" "systemd-timedated")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_info "Restarting $service"
            sudo systemctl restart "$service"
        fi
    done
    
    log_info "Locale set to en_US.UTF-8 and timezone set to America/New_York"
}

# =============================================================================
# COMPLETE SETUP WORKFLOWS
# =============================================================================

# Run all setup functions in logical order
run_all_setup() {
    log_info "Starting complete system setup"
    
    echo -e "${CYAN}=== Flux Complete System Setup v$FLUX_VERSION ===${NC}"
    echo -e "${WHITE}This will run all available setup functions.${NC}"
    echo
    
    if ! prompt_yes_no "Continue with complete setup?" "y"; then
        log_info "Complete setup cancelled by user"
        return 0
    fi
    
    # Check for required modules
    if ! check_modules; then
        return 1
    fi
    
    # Define setup functions in logical order
    local setup_functions=(
        "initial_update_upgrade:System Update & Upgrade"
        "set_locale_and_timezone:Locale & Timezone"
        "change_hostname:Hostname Configuration"
        "add_fluxadmin_user:Create Admin User"
        "install_certificates:Install Certificates"
        "apply_sysctl_hardening:System Hardening"
        "ssh_hardening:SSH Security"
        "install_zsh_omz:ZSH Shell Setup"
        "setup_custom_motd:Custom MOTD"
        "setup_netdata:System Monitoring"
    )
    
    local completed_count=0
    local failed_count=0
    
    for func_info in "${setup_functions[@]}"; do
        IFS=':' read -ra FUNC_PARTS <<< "$func_info"
        local func_name="${FUNC_PARTS[0]}"
        local func_desc="${FUNC_PARTS[1]}"
        
        echo -e "\n${CYAN}=== $func_desc ===${NC}"
        
        if prompt_yes_no "Run $func_desc?" "y"; then
            if $func_name; then
                log_info "$func_desc completed successfully"
                ((completed_count++))
            else
                log_error "$func_desc failed"
                ((failed_count++))
                if ! prompt_yes_no "Continue with remaining functions?" "y"; then
                    break
                fi
            fi
        else
            log_info "Skipping $func_desc"
        fi
    done
    
    # Show completion summary
    echo -e "\n${CYAN}=== Setup Complete ===${NC}"
    echo -e "${GREEN}✓ Completed: $completed_count functions${NC}"
    if [[ $failed_count -gt 0 ]]; then
        echo -e "${RED}✗ Failed: $failed_count functions${NC}"
    fi
    
    log_info "Complete setup finished: $completed_count completed, $failed_count failed"
    
    # Show important information
    echo -e "\n${YELLOW}=== Important Information ===${NC}"
    echo -e "${WHITE}• Review logs: tail -f $LOGFILE${NC}"
    echo -e "${WHITE}• ZSH: Run 'zsh' to start using the new shell${NC}"
    echo -e "${WHITE}• NetData: Access monitoring at http://localhost:19999${NC}"
    echo -e "${WHITE}• SSH: Connection port may have changed - check before disconnecting${NC}"
    
    return 0
}

# Quick setup (essential functions only)
run_quick_setup() {
    log_info "Starting quick system setup"
    
    echo -e "${CYAN}=== Flux Quick Setup v$FLUX_VERSION ===${NC}"
    echo -e "${WHITE}This will run essential setup functions only.${NC}"
    echo
    
    local quick_functions=(
        "initial_update_upgrade:System Update"
        "install_certificates:Certificates"
        "apply_sysctl_hardening:Security Hardening"
        "ssh_hardening:SSH Security"
    )
    
    for func_info in "${quick_functions[@]}"; do
        IFS=':' read -ra FUNC_PARTS <<< "$func_info"
        local func_name="${FUNC_PARTS[0]}"
        local func_desc="${FUNC_PARTS[1]}"
        
        echo -e "\n${CYAN}=== $func_desc ===${NC}"
        if $func_name; then
            log_info "$func_desc completed"
        else
            log_error "$func_desc failed"
        fi
    done
    
    log_info "Quick setup completed"
}

# =============================================================================
# CLEANUP FUNCTION
# =============================================================================

cleanup() {
    log_info "Performing cleanup"
    
    # Remove temporary files
    rm -f /tmp/flux-*.sh
    rm -f /tmp/*_keys.$
    rm -f /tmp/github_keys.*
    rm -f /tmp/valid_keys.*
    rm -f /tmp/ssh_hardening.conf
    rm -f /tmp/netdata-*.sh
    
    log_info "Cleanup completed"
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

usage() {
    cat << EOF
Usage: $0 [options]

Flux System Administration Framework v$FLUX_VERSION

Options:
    -h, --help          Display this help message
    -v, --version       Show version information
    
    # System Configuration
    -n, --hostname      Change the hostname of the system
    -i, --interfaces    Print network interfaces information
    -a, --add-interface Add a network interface
    -l, --locale        Set system locale and timezone
    
    # User Management
    -u, --user          Add fluxadmin user
    
    # Security & Hardening
    -s, --ssh           Configure SSH hardening
    -t, --sysctl        Apply sysctl hardening
    -c, --certs         Install certificates
    
    # System Enhancement
    -z, --zsh           Install ZSH and Oh-My-Zsh
    -m, --motd          Setup custom MOTD
    --update            Update and upgrade system
    --netdata           Setup NetData monitoring
    
    # Workflow Options
    --all               Run complete setup (all functions)
    --quick             Run quick setup (essential functions only)
    --modules           List available modules and their status
    
    # Utility Options
    --check             Check system requirements and modules
    --backup            Create configuration backups
    --status            Show system status

Examples:
    $0 --all                    # Complete system setup
    $0 --quick                  # Essential setup only
    $0 -n -s                    # Change hostname and configure SSH
    $0 --update --certs         # Update system and install certificates
    $0 -z -m --netdata          # Setup ZSH, MOTD, and monitoring
    $0 --modules                # List available modules

Module Integration:
    All functions now use dedicated modules for enhanced functionality.
    Modules are automatically executed with appropriate error handling.

EOF
    exit 0
}

# Show version information
show_version() {
    cat << EOF
Flux System Administration Framework
Version: $FLUX_VERSION
Release: $FLUX_RELEASE
Author: Flux Development Team

Available Modules:
EOF
    
    for module in "${AVAILABLE_MODULES[@]}"; do
        if [[ -f "$SCRIPT_DIR/$module" ]]; then
            echo "  ✓ $module"
        else
            echo "  ✗ $module (missing)"
        fi
    done
    
    echo
    echo "Helper Library: flux-helpers.sh"
    if [[ -f "$SCRIPT_DIR/flux-helpers.sh" ]]; then
        echo "  ✓ Available"
    else
        echo "  ✗ Missing"
    fi
}

# List available modules and their status
list_modules() {
    log_info "Checking module availability"
    
    echo -e "${CYAN}=== Flux Modules Status ===${NC}"
    
    for module in "${AVAILABLE_MODULES[@]}"; do
        local module_path="$SCRIPT_DIR/$module"
        local module_name=$(basename "$module" .sh)
        
        printf "%-20s " "$module_name"
        
        if [[ -f "$module_path" ]]; then
            if [[ -x "$module_path" ]]; then
                echo -e "${GREEN}✓ Available & Executable${NC}"
            else
                echo -e "${YELLOW}✓ Available (making executable)${NC}"
                chmod +x "$module_path"
            fi
        else
            echo -e "${RED}✗ Missing${NC}"
        fi
    done
    
    echo -e "\n${WHITE}Helper Library:${NC}"
    printf "%-20s " "flux-helpers"
    if [[ -f "$SCRIPT_DIR/flux-helpers.sh" ]]; then
        echo -e "${GREEN}✓ Available${NC}"
    else
        echo -e "${RED}✗ Missing (CRITICAL)${NC}"
    fi
}

# Check system requirements and modules
check_system() {
    log_info "Performing system checks"
    
    echo -e "${CYAN}=== System Requirements Check ===${NC}"
    
    # Check operating system
    local distro=$(detect_distro)
    echo -e "${WHITE}Distribution:${NC} $distro"
    
    # Check if running as root/sudo
    if is_root; then
        echo -e "${WHITE}Privileges:${NC} ${GREEN}Root/Sudo${NC}"
    else
        echo -e "${WHITE}Privileges:${NC} ${YELLOW}Regular user (some functions may require sudo)${NC}"
    fi
    
    # Check systemd
    if has_systemd; then
        echo -e "${WHITE}Init System:${NC} ${GREEN}Systemd${NC}"
    else
        echo -e "${WHITE}Init System:${NC} ${YELLOW}Non-systemd (some features may be limited)${NC}"
    fi
    
    # Check disk space
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local space_gb=$((available_space / 1024 / 1024))
    if [[ $space_gb -gt 2 ]]; then
        echo -e "${WHITE}Disk Space:${NC} ${GREEN}${space_gb}GB available${NC}"
    else
        echo -e "${WHITE}Disk Space:${NC} ${YELLOW}${space_gb}GB available (low)${NC}"
    fi
    
    # Check memory
    local memory_gb=$(free -g | awk 'NR==2{print $2}')
    if [[ $memory_gb -gt 1 ]]; then
        echo -e "${WHITE}Memory:${NC} ${GREEN}${memory_gb}GB${NC}"
    else
        echo -e "${WHITE}Memory:${NC} ${YELLOW}${memory_gb}GB (may impact performance)${NC}"
    fi
    
    # Check internet connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${WHITE}Internet:${NC} ${GREEN}Connected${NC}"
    else
        echo -e "${WHITE}Internet:${NC} ${RED}No connectivity${NC}"
    fi
    
    echo -e "\n${CYAN}=== Module Check ===${NC}"
    list_modules
    
    echo -e "\n${GREEN}System check completed${NC}"
}

# Create configuration backups
create_backups() {
    log_info "Creating configuration backups"
    
    local backup_base="/etc/flux-backups/$(date +%Y%m%d_%H%M%S)"
    sudo mkdir -p "$backup_base"
    
    # List of important configuration files to backup
    local config_files=(
        "/etc/ssh/sshd_config"
        "/etc/network/interfaces"
        "/etc/netplan"
        "/etc/hosts"
        "/etc/hostname"
        "/etc/motd"
        "/etc/update-motd.d"
        "/etc/sysctl.d"
        "/etc/netdata"
        "/etc/fail2ban"
        "/etc/ufw"
    )
    
    echo -e "${CYAN}=== Creating Configuration Backups ===${NC}"
    
    for config in "${config_files[@]}"; do
        if [[ -e "$config" ]]; then
            local backup_name=$(basename "$config")
            if [[ -d "$config" ]]; then
                sudo cp -r "$config" "$backup_base/$backup_name"
                echo -e "${GREEN}✓ Backed up directory: $config${NC}"
            else
                sudo cp "$config" "$backup_base/$backup_name"
                echo -e "${GREEN}✓ Backed up file: $config${NC}"
            fi
        fi
    done
    
    # Backup user configurations
    local user_configs=(
        "$HOME/.zshrc"
        "$HOME/.bashrc"
        "$HOME/.ssh"
    )
    
    for config in "${user_configs[@]}"; do
        if [[ -e "$config" ]]; then
            local backup_name=$(basename "$config")
            if [[ -d "$config" ]]; then
                cp -r "$config" "$backup_base/user_$backup_name"
                echo -e "${GREEN}✓ Backed up user directory: $config${NC}"
            else
                cp "$config" "$backup_base/user_$backup_name"
                echo -e "${GREEN}✓ Backed up user file: $config${NC}"
            fi
        fi
    done
    
    # Set proper permissions
    sudo chown -R root:root "$backup_base"
    sudo chmod -R 644 "$backup_base"
    
    echo -e "\n${GREEN}Backup completed: $backup_base${NC}"
    log_info "Configuration backup created at: $backup_base"
}

# Show system status
show_system_status() {
    echo -e "${CYAN}=== Flux System Status ===${NC}"
    
    # System information
    echo -e "${WHITE}System Information:${NC}"
    echo "  Hostname: $(hostname -f)"
    echo "  Uptime: $(uptime -p)"
    echo "  Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
    echo "  Memory: $(free -h | awk 'NR==2{printf "%.1f/%.1fGB (%.0f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}')"
    echo "  Disk: $(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')"
    
    # Service status
    echo -e "\n${WHITE}Critical Services:${NC}"
    local services=("ssh" "ufw" "fail2ban" "netdata" "systemd-resolved")
    
    for service in "${services[@]}"; do
        printf "  %-15s " "$service:"
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "${GREEN}Active${NC}"
        else
            echo -e "${RED}Inactive${NC}"
        fi
    done
    
    # Network status
    echo -e "\n${WHITE}Network Interfaces:${NC}"
    ip -brief addr show | grep -v lo | while read line; do
        echo "  $line"
    done
    
    # Security status
    echo -e "\n${WHITE}Security Status:${NC}"
    
    # Firewall
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(ufw status | head -1 | awk '{print $2}')
        echo "  Firewall (UFW): $ufw_status"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        if systemctl is-active --quiet firewalld; then
            echo "  Firewall (firewalld): Active"
        else
            echo "  Firewall (firewalld): Inactive"
        fi
    else
        echo "  Firewall: Not configured"
    fi
    
    # Updates
    echo -e "\n${WHITE}Update Status:${NC}"
    local distro=$(detect_distro)
    case $distro in
        ubuntu|debian|mint|pop)
            if [[ -f /var/run/reboot-required ]]; then
                echo -e "  ${YELLOW}Reboot required${NC}"
            else
                local updates=$(apt list --upgradable 2>/dev/null | grep -v "WARNING" | wc -l)
                if [[ $updates -gt 0 ]]; then
                    echo "  $updates updates available"
                else
                    echo -e "  ${GREEN}System up to date${NC}"
                fi
            fi
            ;;
        *)
            echo "  Update check not available for this distribution"
            ;;
    esac
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Initialize logging
    init_logging
    log_info "Flux main setup script v$FLUX_VERSION started with args: $*"
    
    # If no arguments, show usage
    if [[ $# -eq 0 ]]; then
        usage
    fi
    
    # Parse command line options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            --modules)
                list_modules
                exit 0
                ;;
            --check)
                check_system
                exit 0
                ;;
            --backup)
                create_backups
                exit 0
                ;;
            --status)
                show_system_status
                exit 0
                ;;
            -n|--hostname)
                change_hostname
                ;;
            -i|--interfaces)
                print_network_interfaces
                ;;
            -a|--add-interface)
                add_network_interface
                ;;
            -l|--locale)
                set_locale_and_timezone
                ;;
            -u|--user)
                add_fluxadmin_user
                ;;
            -s|--ssh)
                ssh_hardening
                ;;
            -t|--sysctl)
                apply_sysctl_hardening
                ;;
            -c|--certs)
                install_certificates
                ;;
            -z|--zsh)
                install_zsh_omz
                ;;
            -m|--motd)
                setup_custom_motd
                ;;
            --update)
                initial_update_upgrade
                ;;
            --netdata)
                setup_netdata
                ;;
            --all)
                run_all_setup
                ;;
            --quick)
                run_quick_setup
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                usage
                ;;
        esac
        shift
    done
    
    # Check if reboot is needed
    check_reboot_needed
    
    log_info "Flux main setup script completed successfully"
}

# Set up exit trap
trap 'check_reboot_needed; cleanup; log_info "Script finished"' EXIT

# Run main function with all arguments
main "$@"#!/bin/bash

# main.sh - Flux system setup script with integrated modules
# Complete system administration and configuration framework

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"