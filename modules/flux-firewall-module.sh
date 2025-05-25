#!/bin/bash

# flux_firewall_module.sh - Firewall configuration module
# Version: 1.0.0
# Manages UFW and firewalld firewall configurations

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/flux_helpers.sh" ]]; then
    source "$SCRIPT_DIR/flux_helpers.sh"
else
    echo "Error: flux_helpers.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Set up error handling
setup_error_handling

# =============================================================================
# CONFIGURATION
# =============================================================================

# Default settings
readonly DEFAULT_INCOMING_POLICY="deny"
readonly DEFAULT_OUTGOING_POLICY="allow"
readonly DEFAULT_FORWARD_POLICY="deny"
readonly DEFAULT_LOGGING="low"

# Common service ports
declare -A SERVICE_PORTS=(
    ["ssh"]="22/tcp"
    ["http"]="80/tcp"
    ["https"]="443/tcp"
    ["ftp"]="21/tcp"
    ["smtp"]="25/tcp"
    ["dns"]="53"
    ["ntp"]="123/udp"
    ["mysql"]="3306/tcp"
    ["postgresql"]="5432/tcp"
    ["redis"]="6379/tcp"
    ["mongodb"]="27017/tcp"
    ["elasticsearch"]="9200/tcp"
    ["docker"]="2376/tcp"
    ["kubernetes-api"]="6443/tcp"
)

# =============================================================================
# FIREWALL DETECTION
# =============================================================================

# Detect active firewall system
detect_firewall() {
    if command -v ufw >/dev/null 2>&1 && ufw status &>/dev/null; then
        echo "ufw"
    elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active firewalld &>/dev/null; then
        echo "firewalld"
    elif command -v iptables >/dev/null 2>&1; then
        echo "iptables"
    else
        echo "none"
    fi
}

# Check if firewall is installed
is_firewall_installed() {
    local fw_type="${1:-$(detect_firewall)}"
    
    case "$fw_type" in
        ufw)
            command -v ufw >/dev/null 2>&1
            ;;
        firewalld)
            command -v firewall-cmd >/dev/null 2>&1
            ;;
        iptables)
            command -v iptables >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# Install firewall
install_firewall() {
    local fw_type="${1:-ufw}"
    local distro=$(detect_distro)
    
    log_info "Installing firewall: $fw_type"
    
    case "$distro" in
        ubuntu|debian|mint|pop)
            case "$fw_type" in
                ufw)
                    sudo apt-get update
                    sudo apt-get install -y ufw
                    ;;
                firewalld)
                    sudo apt-get update
                    sudo apt-get install -y firewalld
                    sudo systemctl stop ufw 2>/dev/null || true
                    sudo systemctl disable ufw 2>/dev/null || true
                    ;;
            esac
            ;;
        centos|fedora|rhel|rocky|almalinux)
            case "$fw_type" in
                ufw)
                    log_warn "UFW is not typically used on Red Hat systems"
                    sudo yum install -y ufw || sudo dnf install -y ufw
                    ;;
                firewalld)
                    sudo yum install -y firewalld || sudo dnf install -y firewalld
                    ;;
            esac
            ;;
    esac
}

# =============================================================================
# UFW MANAGEMENT
# =============================================================================

# Get UFW status
get_ufw_status() {
    if ! command -v ufw >/dev/null 2>&1; then
        echo "not_installed"
        return 1
    fi
    
    if ufw status | grep -q "Status: active"; then
        echo "active"
    else
        echo "inactive"
    fi
}

# Enable UFW
enable_ufw() {
    local force="${1:-false}"
    
    log_info "Enabling UFW firewall"
    
    # Check if UFW is installed
    if ! is_firewall_installed "ufw"; then
        log_error "UFW is not installed"
        return 1
    fi
    
    # Set default policies
    sudo ufw default "$DEFAULT_INCOMING_POLICY" incoming
    sudo ufw default "$DEFAULT_OUTGOING_POLICY" outgoing
    sudo ufw default "$DEFAULT_FORWARD_POLICY" routed
    
    # Enable logging
    sudo ufw logging "$DEFAULT_LOGGING"
    
    # Ensure SSH is allowed before enabling
    local ssh_port=$(grep -E "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
    log_warn "Allowing SSH on port $ssh_port to prevent lockout"
    sudo ufw allow "$ssh_port/tcp" comment "SSH"
    
    # Enable UFW
    if [[ "$force" == "true" ]]; then
        sudo ufw --force enable
    else
        echo -e "${YELLOW}WARNING: Enabling firewall. Ensure you have SSH access configured!${NC}"
        if prompt_yes_no "Enable UFW firewall?" "y"; then
            sudo ufw --force enable
        else
            log_info "UFW enabling cancelled"
            return 0
        fi
    fi
    
    log_info "UFW firewall enabled"
}

# Add UFW rule
add_ufw_rule() {
    local rule_type="$1"  # allow/deny
    local rule_spec="$2"  # port/service/ip
    local comment="${3:-}"
    local direction="${4:-in}"
    
    log_info "Adding UFW rule: $rule_type $rule_spec"
    
    # Build UFW command
    local ufw_cmd=(sudo ufw)
    
    # Add direction for non-simple rules
    if [[ "$rule_spec" =~ ^[0-9]+/(tcp|udp)$ ]] || [[ "$rule_spec" =~ ^[0-9]+$ ]]; then
        # Simple port rule
        ufw_cmd+=("$rule_type" "$rule_spec")
    else
        # Complex rule
        ufw_cmd+=("$rule_type" "$direction")
        
        # Parse rule specification
        if [[ "$rule_spec" =~ ^from ]]; then
            ufw_cmd+=($rule_spec)
        elif [[ "$rule_spec" =~ ^to ]]; then
            ufw_cmd+=($rule_spec)
        else
            ufw_cmd+=("to any port" "$rule_spec")
        fi
    fi
    
    # Add comment if provided
    if [[ -n "$comment" ]]; then
        ufw_cmd+=(comment "$comment")
    fi
    
    # Execute command
    if "${ufw_cmd[@]}"; then
        log_info "UFW rule added successfully"
        return 0
    else
        log_error "Failed to add UFW rule"
        return 1
    fi
}

# List UFW rules
list_ufw_rules() {
    local format="${1:-numbered}"
    
    echo -e "${CYAN}=== UFW Firewall Rules ===${NC}"
    
    local status=$(get_ufw_status)
    echo -e "Status: $([ "$status" = "active" ] && echo -e "${GREEN}$status${NC}" || echo -e "${RED}$status${NC}")"
    echo
    
    if [[ "$status" == "active" ]]; then
        case "$format" in
            numbered)
                sudo ufw status numbered
                ;;
            verbose)
                sudo ufw status verbose
                ;;
            raw)
                sudo ufw show raw
                ;;
        esac
    fi
}

# Delete UFW rule
delete_ufw_rule() {
    local rule_num="$1"
    
    log_info "Deleting UFW rule #$rule_num"
    
    if sudo ufw delete "$rule_num"; then
        log_info "UFW rule deleted successfully"
        return 0
    else
        log_error "Failed to delete UFW rule"
        return 1
    fi
}

# =============================================================================
# FIREWALLD MANAGEMENT
# =============================================================================

# Get firewalld status
get_firewalld_status() {
    if ! command -v firewall-cmd >/dev/null 2>&1; then
        echo "not_installed"
        return 1
    fi
    
    if systemctl is-active firewalld &>/dev/null; then
        echo "active"
    else
        echo "inactive"
    fi
}

# Enable firewalld
enable_firewalld() {
    log_info "Enabling firewalld"
    
    # Check if firewalld is installed
    if ! is_firewall_installed "firewalld"; then
        log_error "firewalld is not installed"
        return 1
    fi
    
    # Start and enable firewalld
    sudo systemctl start firewalld
    sudo systemctl enable firewalld
    
    # Set default zone
    sudo firewall-cmd --set-default-zone=public
    
    # Ensure SSH is allowed
    sudo firewall-cmd --permanent --add-service=ssh
    sudo firewall-cmd --reload
    
    log_info "firewalld enabled"
}

# Add firewalld rule
add_firewalld_rule() {
    local rule_type="$1"  # service/port/rich-rule
    local rule_spec="$2"
    local zone="${3:-public}"
    local permanent="${4:-true}"
    
    log_info "Adding firewalld rule: $rule_type=$rule_spec"
    
    local cmd_args=()
    [[ "$permanent" == "true" ]] && cmd_args+=(--permanent)
    cmd_args+=(--zone="$zone")
    
    case "$rule_type" in
        service)
            cmd_args+=(--add-service="$rule_spec")
            ;;
        port)
            cmd_args+=(--add-port="$rule_spec")
            ;;
        source)
            cmd_args+=(--add-source="$rule_spec")
            ;;
        rich-rule)
            cmd_args+=(--add-rich-rule="$rule_spec")
            ;;
    esac
    
    if sudo firewall-cmd "${cmd_args[@]}"; then
        if [[ "$permanent" == "true" ]]; then
            sudo firewall-cmd --reload
        fi
        log_info "firewalld rule added successfully"
        return 0
    else
        log_error "Failed to add firewalld rule"
        return 1
    fi
}

# List firewalld rules
list_firewalld_rules() {
    local zone="${1:-public}"
    
    echo -e "${CYAN}=== Firewalld Rules (Zone: $zone) ===${NC}"
    
    local status=$(get_firewalld_status)
    echo -e "Status: $([ "$status" = "active" ] && echo -e "${GREEN}$status${NC}" || echo -e "${RED}$status${NC}")"
    echo
    
    if [[ "$status" == "active" ]]; then
        echo -e "${WHITE}Active Zone:${NC} $(firewall-cmd --get-active-zones | head -1)"
        echo -e "${WHITE}Default Zone:${NC} $(firewall-cmd --get-default-zone)"
        echo
        
        echo -e "${WHITE}Services:${NC}"
        firewall-cmd --zone="$zone" --list-services | tr ' ' '\n' | sed 's/^/  /'
        echo
        
        echo -e "${WHITE}Ports:${NC}"
        firewall-cmd --zone="$zone" --list-ports | tr ' ' '\n' | sed 's/^/  /'
        echo
        
        echo -e "${WHITE}Rich Rules:${NC}"
        firewall-cmd --zone="$zone" --list-rich-rules | sed 's/^/  /'
    fi
}

# =============================================================================
# COMMON FIREWALL OPERATIONS
# =============================================================================

# Configure common services
configure_common_services() {
    local fw_type="${1:-$(detect_firewall)}"
    
    echo -e "${CYAN}=== Configure Common Services ===${NC}"
    echo -e "${WHITE}Available services:${NC}"
    
    # List services
    local i=1
    for service in "${!SERVICE_PORTS[@]}"; do
        echo "  $i) $service (${SERVICE_PORTS[$service]})"
        ((i++))
    done | sort -k2
    
    echo
    read -p "Enter service numbers to allow (comma-separated): " selections
    
    IFS=',' read -ra selected <<< "$selections"
    
    # Get service names array
    local service_names=($(printf '%s\n' "${!SERVICE_PORTS[@]}" | sort))
    
    for sel in "${selected[@]}"; do
        sel=$((sel - 1))  # Convert to 0-based index
        if [[ $sel -ge 0 && $sel -lt ${#service_names[@]} ]]; then
            local service="${service_names[$sel]}"
            local port="${SERVICE_PORTS[$service]}"
            
            case "$fw_type" in
                ufw)
                    add_ufw_rule "allow" "$port" "$service"
                    ;;
                firewalld)
                    # Try to add as service first, then as port
                    if ! add_firewalld_rule "service" "$service" 2>/dev/null; then
                        add_firewalld_rule "port" "$port"
                    fi
                    ;;
            esac
        fi
    done
}

# Configure application profile
configure_application_profile() {
    local app_name="$1"
    local ports="$2"
    local fw_type="${3:-$(detect_firewall)}"
    
    log_info "Configuring firewall for application: $app_name"
    
    case "$fw_type" in
        ufw)
            # Create UFW application profile
            local profile_file="/etc/ufw/applications.d/$app_name"
            sudo tee "$profile_file" > /dev/null << EOF
[$app_name]
title=$app_name
description=$app_name Application
ports=$ports
EOF
            sudo ufw app update "$app_name"
            add_ufw_rule "allow" "$app_name"
            ;;
            
        firewalld)
            # Create firewalld service
            local service_file="/etc/firewalld/services/${app_name}.xml"
            local port_entries=""
            
            # Parse ports
            IFS=',' read -ra port_list <<< "$ports"
            for port_spec in "${port_list[@]}"; do
                if [[ "$port_spec" =~ ^([0-9]+)/(.+)$ ]]; then
                    port_entries+="  <port protocol=\"${BASH_REMATCH[2]}\" port=\"${BASH_REMATCH[1]}\"/>\n"
                fi
            done
            
            sudo tee "$service_file" > /dev/null << EOF
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>$app_name</short>
  <description>$app_name Application</description>
$(echo -e "$port_entries")
</service>
EOF
            sudo firewall-cmd --reload
            add_firewalld_rule "service" "$app_name"
            ;;
    esac
}

# =============================================================================
# SECURITY PRESETS
# =============================================================================

# Apply security preset
apply_security_preset() {
    local preset="$1"
    local fw_type="${2:-$(detect_firewall)}"
    
    log_info "Applying security preset: $preset"
    
    case "$preset" in
        web-server)
            # Web server preset
            local services=("ssh" "http" "https")
            ;;
        database-server)
            # Database server preset
            local services=("ssh" "mysql" "postgresql")
            ;;
        mail-server)
            # Mail server preset
            local services=("ssh" "smtp" "587/tcp" "993/tcp" "995/tcp")
            ;;
        docker-host)
            # Docker host preset
            local services=("ssh" "docker" "2377/tcp" "7946/tcp" "7946/udp" "4789/udp")
            ;;
        kubernetes-node)
            # Kubernetes node preset
            local services=("ssh" "kubernetes-api" "10250/tcp" "10251/tcp" "10252/tcp")
            ;;
        minimal)
            # Minimal preset (SSH only)
            local services=("ssh")
            ;;
    esac
    
    # Apply rules
    for service in "${services[@]}"; do
        case "$fw_type" in
            ufw)
                if [[ -n "${SERVICE_PORTS[$service]}" ]]; then
                    add_ufw_rule "allow" "${SERVICE_PORTS[$service]}" "$service"
                else
                    add_ufw_rule "allow" "$service"
                fi
                ;;
            firewalld)
                if [[ "$service" =~ / ]]; then
                    add_firewalld_rule "port" "$service"
                else
                    add_firewalld_rule "service" "$service"
                fi
                ;;
        esac
    done
    
    log_info "Security preset $preset applied"
}

# =============================================================================
# BACKUP AND RESTORE
# =============================================================================

# Backup firewall rules
backup_firewall_rules() {
    local fw_type="${1:-$(detect_firewall)}"
    local backup_dir="/etc/firewall-backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    sudo mkdir -p "$backup_dir"
    
    case "$fw_type" in
        ufw)
            local backup_file="$backup_dir/ufw_rules_$timestamp.txt"
            sudo ufw status numbered > "$backup_file"
            sudo cp -r /etc/ufw "$backup_dir/ufw_config_$timestamp"
            log_info "UFW rules backed up to: $backup_file"
            ;;
        firewalld)
            local backup_file="$backup_dir/firewalld_rules_$timestamp.xml"
            sudo firewall-cmd --list-all-zones > "$backup_file"
            sudo cp -r /etc/firewalld "$backup_dir/firewalld_config_$timestamp"
            log_info "Firewalld rules backed up to: $backup_file"
            ;;
    esac
    
    echo "$backup_file"
}

# Restore firewall rules
restore_firewall_rules() {
    local backup_file="$1"
    local fw_type="${2:-$(detect_firewall)}"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_warn "Restoring firewall rules from: $backup_file"
    
    if ! prompt_yes_no "This will replace current rules. Continue?" "n"; then
        return 0
    fi
    
    case "$fw_type" in
        ufw)
            # Reset UFW
            sudo ufw --force reset
            
            # Restore from backup
            if [[ "$backup_file" =~ ufw_config_ ]]; then
                sudo cp -r "$backup_file"/* /etc/ufw/
                sudo ufw --force enable
            else
                log_error "Cannot restore from this backup format"
                return 1
            fi
            ;;
        firewalld)
            # Restore firewalld config
            if [[ "$backup_file" =~ firewalld_config_ ]]; then
                sudo systemctl stop firewalld
                sudo cp -r "$backup_file"/* /etc/firewalld/
                sudo systemctl start firewalld
                sudo firewall-cmd --reload
            else
                log_error "Cannot restore from this backup format"
                return 1
            fi
            ;;
    esac
    
    log_info "Firewall rules restored"
}

# =============================================================================
# INTERACTIVE CONFIGURATION
# =============================================================================

# Interactive firewall setup
firewall_setup_wizard() {
    echo -e "${CYAN}=== Firewall Setup Wizard ===${NC}"
    
    # Detect current firewall
    local current_fw=$(detect_firewall)
    echo -e "\nCurrent firewall: ${WHITE}$current_fw${NC}"
    
    # Select firewall type
    local fw_type="$current_fw"
    if [[ "$current_fw" == "none" ]] || prompt_yes_no "Change firewall type?" "n"; then
        echo -e "\n${WHITE}Select firewall type:${NC}"
        echo "1) UFW (Ubuntu Firewall)"
        echo "2) firewalld (Red Hat/CentOS)"
        echo "3) Cancel"
        
        read -p "Select option [1-3]: " fw_choice
        
        case "$fw_choice" in
            1) fw_type="ufw" ;;
            2) fw_type="firewalld" ;;
            *) return 0 ;;
        esac
        
        # Install if needed
        if ! is_firewall_installed "$fw_type"; then
            install_firewall "$fw_type"
        fi
    fi
    
    # Enable firewall
    case "$fw_type" in
        ufw)
            if [[ "$(get_ufw_status)" != "active" ]]; then
                enable_ufw
            fi
            ;;
        firewalld)
            if [[ "$(get_firewalld_status)" != "active" ]]; then
                enable_firewalld
            fi
            ;;
    esac
    
    # Configure rules
    echo -e "\n${WHITE}Configuration Options:${NC}"
    echo "1) Apply security preset"
    echo "2) Configure common services"
    echo "3) Add custom rule"
    echo "4) Skip"
    
    read -p "Select option [1-4]: " config_choice
    
    case "$config_choice" in
        1)
            echo -e "\n${WHITE}Security Presets:${NC}"
            echo "1) Web Server (SSH, HTTP, HTTPS)"
            echo "2) Database Server (SSH, MySQL, PostgreSQL)"
            echo "3) Mail Server (SSH, SMTP, IMAP, POP3)"
            echo "4) Docker Host"
            echo "5) Kubernetes Node"
            echo "6) Minimal (SSH only)"
            
            read -p "Select preset [1-6]: " preset_choice
            
            case "$preset_choice" in
                1) apply_security_preset "web-server" "$fw_type" ;;
                2) apply_security_preset "database-server" "$fw_type" ;;
                3) apply_security_preset "mail-server" "$fw_type" ;;
                4) apply_security_preset "docker-host" "$fw_type" ;;
                5) apply_security_preset "kubernetes-node" "$fw_type" ;;
                6) apply_security_preset "minimal" "$fw_type" ;;
            esac
            ;;
        2)
            configure_common_services "$fw_type"
            ;;
        3)
            # Add custom rule
            read -p "Enter port or service: " port_spec
            read -p "Enter comment (optional): " comment
            
            case "$fw_type" in
                ufw)
                    add_ufw_rule "allow" "$port_spec" "$comment"
                    ;;
                firewalld)
                    if [[ "$port_spec" =~ / ]]; then
                        add_firewalld_rule "port" "$port_spec"
                    else
                        add_firewalld_rule "service" "$port_spec"
                    fi
                    ;;
            esac
            ;;
    esac
    
    # Show final status
    echo -e "\n${GREEN}Firewall configuration completed!${NC}"
    case "$fw_type" in
        ufw)
            list_ufw_rules
            ;;
        firewalld)
            list_firewalld_rules
            ;;
    esac
}

# =============================================================================
# STATUS AND MONITORING
# =============================================================================

# Show firewall status
show_firewall_status() {
    local fw_type="${1:-$(detect_firewall)}"
    
    echo -e "${CYAN}=== Firewall Status ===${NC}"
    echo -e "Type: ${WHITE}$fw_type${NC}"
    
    case "$fw_type" in
        ufw)
            local status=$(get_ufw_status)
            echo -e "Status: $([ "$status" = "active" ] && echo -e "${GREEN}$status${NC}" || echo -e "${RED}$status${NC}")"
            
            if [[ "$status" == "active" ]]; then
                echo -e "\n${WHITE}Statistics:${NC}"
                # Get connection tracking info
                local conntrack=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null || echo "N/A")
                local conntrack_max=$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || echo "N/A")
                echo "  Active connections: $conntrack / $conntrack_max"
                
                # Get rule count
                local rule_count=$(sudo ufw status numbered | grep -c '^\[' || echo "0")
                echo "  Active rules: $rule_count"
            fi
            ;;
        firewalld)
            local status=$(get_firewalld_status)
            echo -e "Status: $([ "$status" = "active" ] && echo -e "${GREEN}$status${NC}" || echo -e "${RED}$status${NC}")"
            
            if [[ "$status" == "active" ]]; then
                echo -e "\n${WHITE}Active Configuration:${NC}"
                echo "  Default Zone: $(firewall-cmd --get-default-zone)"
                echo "  Active Zones: $(firewall-cmd --get-active-zones | grep -v "^  " | tr '\n' ' ')"
                
                # Get service/port counts
                local service_count=$(firewall-cmd --list-services | wc -w)
                local port_count=$(firewall-cmd --list-ports | wc -w)
                echo "  Services: $service_count"
                echo "  Ports: $port_count"
            fi
            ;;
        none)
            echo -e "Status: ${RED}No firewall detected${NC}"
            echo -e "${YELLOW}Warning: System is not protected by a firewall!${NC}"
            ;;
    esac
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

usage() {
    cat << EOF
Usage: $0 [options]

Firewall configuration and management module.

Options:
    -h, --help              Display this help message
    -s, --status            Show firewall status
    -w, --wizard            Run interactive setup wizard
    -e, --enable [TYPE]     Enable firewall (ufw/firewalld)
    -d, --disable           Disable firewall
    -l, --list              List firewall rules
    -a, --allow PORT        Allow port/service
    -r, --remove RULE       Remove rule (by number or spec)
    -p, --preset PRESET     Apply security preset
    --backup                Backup current rules
    --restore FILE          Restore rules from backup

Security Presets:
    web-server              Web server (SSH, HTTP, HTTPS)
    database-server         Database server (SSH, MySQL, PostgreSQL)
    mail-server             Mail server (SSH, SMTP, IMAP, POP3)
    docker-host             Docker host
    kubernetes-node         Kubernetes node
    minimal                 Minimal (SSH only)

Examples:
    $0 -s                   # Show status
    $0 -w                   # Run setup wizard
    $0 -a 8080/tcp          # Allow port 8080
    $0 -p web-server        # Apply web server preset
    $0 --backup             # Backup current rules

EOF
    exit 0
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local action="status"
    local extra_args=()
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -s|--status)
                action="status"
                shift
                ;;
            -w|--wizard)
                action="wizard"
                shift
                ;;
            -e|--enable)
                action="enable"
                [[ "$2" != "-"* ]] && extra_args=("$2") && shift
                shift
                ;;
            -d|--disable)
                action="disable"
                shift
                ;;
            -l|--list)
                action="list"
                shift
                ;;
            -a|--allow)
                action="allow"
                extra_args=("$2")
                shift 2
                ;;
            -r|--remove)
                action="remove"
                extra_args=("$2")
                shift 2
                ;;
            -p|--preset)
                action="preset"
                extra_args=("$2")
                shift 2
                ;;
            --backup)
                action="backup"
                shift
                ;;
            --restore)
                action="restore"
                extra_args=("$2")
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    log_info "Flux firewall module started"
    
    # Detect firewall type
    local fw_type=$(detect_firewall)
    
    # Execute action
    case "$action" in
        status)
            show_firewall_status
            ;;
        wizard)
            firewall_setup_wizard
            ;;
        enable)
            local target_fw="${extra_args[0]:-$fw_type}"
            if [[ "$target_fw" == "none" ]]; then
                target_fw="ufw"  # Default to UFW
            fi
            
            # Install if needed
            if ! is_firewall_installed "$target_fw"; then
                install_firewall "$target_fw"
            fi
            
            # Enable
            case "$target_fw" in
                ufw) enable_ufw ;;
                firewalld) enable_firewalld ;;
            esac
            ;;
        disable)
            case "$fw_type" in
                ufw)
                    sudo ufw disable
                    log_info "UFW disabled"
                    ;;
                firewalld)
                    sudo systemctl stop firewalld
                    sudo systemctl disable firewalld
                    log_info "firewalld disabled"
                    ;;
            esac
            ;;
        list)
            case "$fw_type" in
                ufw) list_ufw_rules ;;
                firewalld) list_firewalld_rules ;;
                *) log_error "No active firewall found" ;;
            esac
            ;;
        allow)
            if [[ -z "${extra_args[0]}" ]]; then
                log_error "Port/service specification required"
                exit 1
            fi
            
            case "$fw_type" in
                ufw)
                    add_ufw_rule "allow" "${extra_args[0]}"
                    ;;
                firewalld)
                    if [[ "${extra_args[0]}" =~ / ]]; then
                        add_firewalld_rule "port" "${extra_args[0]}"
                    else
                        add_firewalld_rule "service" "${extra_args[0]}"
                    fi
                    ;;
                *)
                    log_error "No active firewall found"
                    ;;
            esac
            ;;
        remove)
            if [[ -z "${extra_args[0]}" ]]; then
                log_error "Rule specification required"
                exit 1
            fi
            
            case "$fw_type" in
                ufw)
                    delete_ufw_rule "${extra_args[0]}"
                    ;;
                firewalld)
                    # Implement firewalld rule removal
                    log_error "Firewalld rule removal not yet implemented"
                    ;;
            esac
            ;;
        preset)
            if [[ -z "${extra_args[0]}" ]]; then
                log_error "Preset name required"
                echo "Available presets: web-server, database-server, mail-server, docker-host, kubernetes-node, minimal"
                exit 1
            fi
            apply_security_preset "${extra_args[0]}"
            ;;
        backup)
            backup_firewall_rules
            ;;
        restore)
            if [[ -z "${extra_args[0]}" ]]; then
                log_error "Backup file required"
                exit 1
            fi
            restore_firewall_rules "${extra_args[0]}"
            ;;
    esac
}

# Run main function
main "$@"
