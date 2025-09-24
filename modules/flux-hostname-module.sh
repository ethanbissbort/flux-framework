#!/bin/bash

# flux_hostname_module.sh - Hostname configuration module
# Version: 1.0.0
# Manages system hostname and FQDN configuration

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../flux-helpers.sh" ]]; then
    source "$SCRIPT_DIR/../flux-helpers.sh"
else
    echo "Error: flux-helpers.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Set up error handling
setup_error_handling

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly HOSTNAME_FILE="/etc/hostname"
readonly HOSTS_FILE="/etc/hosts"
readonly MACHINE_INFO_FILE="/etc/machine-info"

# =============================================================================
# HOSTNAME FUNCTIONS
# =============================================================================

# Get current hostname info
get_hostname_info() {
    local current_hostname=$(hostname 2>/dev/null || echo "unknown")
    local current_fqdn=$(hostname -f 2>/dev/null || echo "")
    local current_domain=$(hostname -d 2>/dev/null || echo "")
    local current_short=$(hostname -s 2>/dev/null || echo "$current_hostname")
    
    echo "hostname=$current_hostname"
    echo "fqdn=$current_fqdn"
    echo "domain=$current_domain"
    echo "short=$current_short"
}

# Validate hostname/FQDN with detailed error
validate_hostname_detailed() {
    local name="$1"
    local type="${2:-hostname}"  # hostname or fqdn
    
    # Check basic format
    if ! validate_hostname "$name"; then
        echo "Basic validation failed"
        return 1
    fi
    
    # Additional checks for FQDN
    if [[ "$type" == "fqdn" ]]; then
        # Must contain at least one dot
        if [[ ! "$name" =~ \. ]]; then
            echo "FQDN must contain a domain (e.g., host.domain.com)"
            return 1
        fi
        
        # Check each label
        IFS='.' read -ra LABELS <<< "$name"
        for label in "${LABELS[@]}"; do
            if [[ ${#label} -gt 63 ]]; then
                echo "Each part must be 63 characters or less"
                return 1
            fi
            if [[ ! "$label" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
                echo "Invalid format in part: $label"
                return 1
            fi
        done
    fi
    
    return 0
}

# Set hostname
set_hostname() {
    local new_hostname="$1"
    local update_hosts="${2:-true}"
    
    log_info "Setting hostname to: $new_hostname"
    
    # Backup configuration files
    backup_file "$HOSTNAME_FILE"
    backup_file "$HOSTS_FILE"
    
    # Validate hostname
    local validation_error=$(validate_hostname_detailed "$new_hostname" "hostname")
    if [[ $? -ne 0 ]]; then
        log_error "Invalid hostname: $validation_error"
        return 1
    fi
    
    # Set hostname using hostnamectl if available
    if command -v hostnamectl >/dev/null 2>&1; then
        log_info "Using hostnamectl to set hostname"
        
        sudo hostnamectl set-hostname "$new_hostname" --static
        sudo hostnamectl set-hostname "$new_hostname" --transient
        
        # Also set pretty hostname if it's a simple name
        if [[ ! "$new_hostname" =~ \. ]]; then
            sudo hostnamectl set-hostname "$new_hostname" --pretty
        fi
    else
        # Fallback method
        log_info "Using traditional method to set hostname"
        
        echo "$new_hostname" | sudo tee "$HOSTNAME_FILE" >/dev/null
        sudo hostname "$new_hostname"
    fi
    
    # Update hosts file if requested
    if [[ "$update_hosts" == "true" ]]; then
        update_hosts_file "$new_hostname"
    fi
    
    # Update machine-info if it exists
    if [[ -f "$MACHINE_INFO_FILE" ]]; then
        if grep -q "^PRETTY_HOSTNAME=" "$MACHINE_INFO_FILE"; then
            sudo sed -i "s/^PRETTY_HOSTNAME=.*/PRETTY_HOSTNAME=\"$new_hostname\"/" "$MACHINE_INFO_FILE"
        else
            echo "PRETTY_HOSTNAME=\"$new_hostname\"" | sudo tee -a "$MACHINE_INFO_FILE" >/dev/null
        fi
    fi
    
    log_info "Hostname set successfully"
}

# Set FQDN
set_fqdn() {
    local new_fqdn="$1"
    
    log_info "Setting FQDN to: $new_fqdn"
    
    # Validate FQDN
    local validation_error=$(validate_hostname_detailed "$new_fqdn" "fqdn")
    if [[ $? -ne 0 ]]; then
        log_error "Invalid FQDN: $validation_error"
        return 1
    fi
    
    # Extract hostname and domain
    local new_hostname=$(echo "$new_fqdn" | cut -d. -f1)
    local new_domain=$(echo "$new_fqdn" | cut -d. -f2-)
    
    log_info "Extracted hostname: $new_hostname"
    log_info "Extracted domain: $new_domain"
    
    # Set the hostname
    set_hostname "$new_hostname" false
    
    # Update hosts file with FQDN
    update_hosts_file "$new_hostname" "$new_fqdn"
    
    # Set domain in resolv.conf if not already set
    if [[ -f /etc/resolv.conf ]] && ! grep -q "^domain " /etc/resolv.conf; then
        if ! grep -q "^search " /etc/resolv.conf; then
            echo "domain $new_domain" | sudo tee -a /etc/resolv.conf >/dev/null
        fi
    fi
    
    log_info "FQDN set successfully"
}

# Update hosts file
update_hosts_file() {
    local hostname="$1"
    local fqdn="${2:-}"
    
    log_info "Updating $HOSTS_FILE"
    
    # Get primary IP address
    local primary_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [[ -z "$primary_ip" ]]; then
        primary_ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    fi
    
    # Create new hosts entries
    local new_hosts="/tmp/hosts.new.$$"
    
    # Preserve existing entries but remove old hostname entries
    grep -v -E "^(127\.0\.1\.1|::1).*$hostname" "$HOSTS_FILE" | \
    grep -v -E "^$primary_ip.*$hostname" > "$new_hosts"
    
    # Add new entries
    if [[ -n "$fqdn" && "$fqdn" != "$hostname" ]]; then
        # Add both FQDN and short hostname
        echo "127.0.1.1 $fqdn $hostname" >> "$new_hosts"
        if [[ -n "$primary_ip" ]]; then
            echo "$primary_ip $fqdn $hostname" >> "$new_hosts"
        fi
    else
        # Just hostname
        echo "127.0.1.1 $hostname" >> "$new_hosts"
        if [[ -n "$primary_ip" ]]; then
            echo "$primary_ip $hostname" >> "$new_hosts"
        fi
    fi
    
    # Ensure localhost entries exist
    if ! grep -q "^127.0.0.1.*localhost" "$new_hosts"; then
        sed -i '1i127.0.0.1 localhost' "$new_hosts"
    fi
    
    if ! grep -q "^::1.*localhost" "$new_hosts"; then
        echo "::1 localhost ip6-localhost ip6-loopback" >> "$new_hosts"
    fi
    
    # Apply new hosts file
    sudo mv "$new_hosts" "$HOSTS_FILE"
    sudo chmod 644 "$HOSTS_FILE"
    
    log_info "Hosts file updated"
}

# =============================================================================
# INTERACTIVE FUNCTIONS
# =============================================================================

# Interactive hostname configuration
configure_hostname_interactive() {
    echo -e "${CYAN}=== Hostname Configuration ===${NC}"
    
    # Show current configuration
    echo -e "\n${WHITE}Current Configuration:${NC}"
    eval "$(get_hostname_info)"
    echo "  Hostname: $hostname"
    echo "  FQDN: ${fqdn:-Not set}"
    echo "  Domain: ${domain:-Not set}"
    echo
    
    # Ask what to configure
    echo "What would you like to configure?"
    echo "  1) Simple hostname only"
    echo "  2) Fully Qualified Domain Name (FQDN)"
    echo "  3) Cancel"
    echo
    
    local choice
    read -p "Select option [1-3]: " choice
    
    case "$choice" in
        1)
            # Simple hostname
            local new_hostname=$(prompt_with_validation \
                "Enter new hostname" \
                "validate_hostname" \
                "" \
                "Invalid hostname format. Use only letters, numbers, and hyphens.")
            
            if [[ -n "$new_hostname" ]]; then
                set_hostname "$new_hostname"
                echo -e "\n${GREEN}Hostname set to: $new_hostname${NC}"
            fi
            ;;
            
        2)
            # FQDN
            echo -e "\n${YELLOW}Note: FQDN should be in format: hostname.domain.tld${NC}"
            echo -e "${YELLOW}Example: server01.example.com${NC}\n"
            
            local new_fqdn
            while true; do
                read -p "Enter new FQDN: " new_fqdn
                
                if [[ -z "$new_fqdn" ]]; then
                    log_info "Configuration cancelled"
                    return 0
                fi
                
                local validation_error=$(validate_hostname_detailed "$new_fqdn" "fqdn")
                if [[ $? -eq 0 ]]; then
                    break
                else
                    echo -e "${RED}Error: $validation_error${NC}"
                fi
            done
            
            set_fqdn "$new_fqdn"
            echo -e "\n${GREEN}FQDN set to: $new_fqdn${NC}"
            ;;
            
        3)
            log_info "Configuration cancelled"
            return 0
            ;;
            
        *)
            log_error "Invalid option"
            return 1
            ;;
    esac
    
    # Show new configuration
    echo -e "\n${WHITE}New Configuration:${NC}"
    eval "$(get_hostname_info)"
    echo "  Hostname: $hostname"
    echo "  FQDN: ${fqdn:-Not set}"
    echo "  Domain: ${domain:-Not set}"
    
    # Check if services need restart
    local services_to_restart=()
    
    # Check common services that might need restart
    for service in ssh rsyslog postfix nginx apache2 mysql postgresql; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            services_to_restart+=("$service")
        fi
    done
    
    if [[ ${#services_to_restart[@]} -gt 0 ]]; then
        echo -e "\n${YELLOW}The following services may need to be restarted:${NC}"
        printf '%s\n' "${services_to_restart[@]}" | sed 's/^/  - /'
        
        if prompt_yes_no "Restart these services now?" "n"; then
            for service in "${services_to_restart[@]}"; do
                log_info "Restarting $service"
                sudo systemctl restart "$service"
            done
        fi
    fi
    
    echo -e "\n${YELLOW}Note: You may need to reconnect SSH sessions for changes to take effect${NC}"
}

# =============================================================================
# VERIFICATION FUNCTIONS
# =============================================================================

# Verify hostname configuration
verify_hostname_config() {
    echo -e "${CYAN}=== Hostname Configuration Verification ===${NC}"
    
    local all_good=true
    
    # Get current info
    eval "$(get_hostname_info)"
    
    # Check hostname command
    echo -n "Hostname command: "
    if [[ -n "$hostname" && "$hostname" != "localhost" ]]; then
        echo -e "${GREEN}$hostname${NC}"
    else
        echo -e "${RED}Not set properly${NC}"
        all_good=false
    fi
    
    # Check /etc/hostname
    echo -n "/etc/hostname: "
    if [[ -f "$HOSTNAME_FILE" ]]; then
        local file_hostname=$(cat "$HOSTNAME_FILE")
        if [[ "$file_hostname" == "$hostname" ]]; then
            echo -e "${GREEN}$file_hostname${NC}"
        else
            echo -e "${YELLOW}$file_hostname (mismatch)${NC}"
            all_good=false
        fi
    else
        echo -e "${RED}File not found${NC}"
        all_good=false
    fi
    
    # Check FQDN resolution
    echo -n "FQDN resolution: "
    if [[ -n "$fqdn" ]]; then
        echo -e "${GREEN}$fqdn${NC}"
    else
        echo -e "${YELLOW}Not set${NC}"
    fi
    
    # Check /etc/hosts
    echo -n "/etc/hosts entries: "
    local hosts_ok=true
    if grep -q "$hostname" "$HOSTS_FILE"; then
        echo -e "${GREEN}Found${NC}"
        
        # Show relevant entries
        echo "  Entries containing hostname:"
        grep "$hostname" "$HOSTS_FILE" | sed 's/^/    /'
    else
        echo -e "${RED}Not found${NC}"
        hosts_ok=false
        all_good=false
    fi
    
    # DNS resolution test
    echo -n "DNS resolution test: "
    if host "$hostname" >/dev/null 2>&1; then
        local resolved_ip=$(host "$hostname" | awk '/has address/ {print $4}' | head -1)
        echo -e "${GREEN}OK ($resolved_ip)${NC}"
    else
        echo -e "${YELLOW}Cannot resolve (this is normal for local hostnames)${NC}"
    fi
    
    # Overall status
    echo
    if [[ "$all_good" == "true" ]]; then
        echo -e "${GREEN}✓ Hostname configuration is correct${NC}"
    else
        echo -e "${YELLOW}⚠ Some issues detected with hostname configuration${NC}"
    fi
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

usage() {
    cat << EOF
Usage: $0 [options]

Hostname and FQDN configuration module.

Options:
    -h, --help              Display this help message
    -s, --show              Show current hostname configuration
    -n, --hostname NAME     Set hostname
    -f, --fqdn FQDN        Set fully qualified domain name
    -i, --interactive       Interactive configuration
    -v, --verify           Verify hostname configuration

Examples:
    $0 -s                   # Show current configuration
    $0 -n webserver         # Set hostname to 'webserver'
    $0 -f web.example.com   # Set FQDN
    $0 -i                   # Interactive setup
    $0 -v                   # Verify configuration

Notes:
    - Hostname: Simple name without dots (e.g., 'webserver')
    - FQDN: Full name with domain (e.g., 'webserver.example.com')
    - Changes may require service restarts or reconnection

EOF
    exit 0
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local action="show"
    local hostname_value=""
    local fqdn_value=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -s|--show)
                action="show"
                shift
                ;;
            -n|--hostname)
                action="hostname"
                hostname_value="$2"
                shift 2
                ;;
            -f|--fqdn)
                action="fqdn"
                fqdn_value="$2"
                shift 2
                ;;
            -i|--interactive)
                action="interactive"
                shift
                ;;
            -v|--verify)
                action="verify"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    log_info "Flux hostname module started"
    
    # Execute action
    case "$action" in
        show)
            echo -e "${CYAN}=== Current Hostname Configuration ===${NC}"
            eval "$(get_hostname_info)"
            echo "Hostname: $hostname"
            echo "FQDN: ${fqdn:-Not set}"
            echo "Domain: ${domain:-Not set}"
            echo "Short: $short"
            
            if command -v hostnamectl >/dev/null 2>&1; then
                echo -e "\n${WHITE}Hostnamectl output:${NC}"
                hostnamectl status
            fi
            ;;
            
        hostname)
            if [[ -z "$hostname_value" ]]; then
                log_error "Hostname value required"
                exit 1
            fi
            set_hostname "$hostname_value"
            ;;
            
        fqdn)
            if [[ -z "$fqdn_value" ]]; then
                log_error "FQDN value required"
                exit 1
            fi
            set_fqdn "$fqdn_value"
            ;;
            
        interactive)
            configure_hostname_interactive
            ;;
            
        verify)
            verify_hostname_config
            ;;
    esac
}

# Run main function
main "$@"
