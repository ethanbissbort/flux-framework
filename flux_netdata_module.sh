#!/bin/bash

# flux-netdata.sh - NetData monitoring setup module
# Installs and configures NetData system monitoring

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/flux-helpers.sh" ]]; then
    source "$SCRIPT_DIR/flux-helpers.sh"
else
    echo "Error: flux-helpers.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Set up error handling
setup_error_handling

# =============================================================================
# CONFIGURATION
# =============================================================================

# NetData configuration
readonly NETDATA_INSTALLER_URL="https://my-netdata.io/kickstart.sh"
readonly NETDATA_CONFIG_DIR="/etc/netdata"
readonly NETDATA_WEB_DIR="/usr/share/netdata/web"
readonly NETDATA_LOG_DIR="/var/log/netdata"
readonly NETDATA_PORT="19999"
readonly NETDATA_USER="netdata"

# Default claim room for Flux installations
readonly DEFAULT_CLAIM_ROOMS="flux-systems"

# =============================================================================
# NETDATA INSTALLATION FUNCTIONS
# =============================================================================

# Check system requirements
check_netdata_requirements() {
    log_info "Checking NetData system requirements"
    
    # Check available memory (minimum 512MB recommended)
    local available_memory=$(free -m | awk 'NR==2{print $2}')
    if [[ $available_memory -lt 512 ]]; then
        log_warn "System has less than 512MB RAM ($available_memory MB). NetData may impact performance."
        if ! prompt_yes_no "Continue with installation anyway?" "n"; then
            return 1
        fi
    fi
    
    # Check disk space (minimum 100MB for installation + logs)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local min_space=102400  # 100MB in KB
    if [[ $available_space -lt $min_space ]]; then
        log_error "Insufficient disk space. Available: $(($available_space/1024))MB, Required: 100MB"
        return 1
    fi
    
    # Check if port 19999 is already in use
    if netstat -tuln 2>/dev/null | grep -q ":$NETDATA_PORT "; then
        log_warn "Port $NETDATA_PORT is already in use"
        if ! prompt_yes_no "Continue anyway? (NetData may fail to start)" "n"; then
            return 1
        fi
    fi
    
    log_info "System requirements check passed"
    return 0
}

# Download NetData installer
download_netdata_installer() {
    log_info "Downloading NetData installer"
    
    local installer="/tmp/netdata-kickstart.sh"
    
    if safe_download "$NETDATA_INSTALLER_URL" "$installer"; then
        chmod +x "$installer"
        log_info "NetData installer downloaded successfully"
        echo "$installer"
        return 0
    else
        log_error "Failed to download NetData installer"
        return 1
    fi
}

# Install NetData
install_netdata() {
    local claim_token="${1:-}"
    local claim_rooms="${2:-$DEFAULT_CLAIM_ROOMS}"
    local claim_proxy="${3:-}"
    local auto_update="${4:-true}"
    
    log_info "Installing NetData"
    
    # Download installer
    local installer
    if ! installer=$(download_netdata_installer); then
        return 1
    fi
    
    # Prepare installation options
    local install_options=(
        "--dont-wait"
        "--disable-telemetry"
    )
    
    # Add auto-update option
    if [[ "$auto_update" == "false" ]]; then
        install_options+=("--no-updates")
    fi
    
    # Add claim options if token provided
    if [[ -n "$claim_token" ]]; then
        log_info "Installing NetData with cloud integration"
        install_options+=(
            "--claim-token" "$claim_token"
            "--claim-rooms" "$claim_rooms"
        )
        
        if [[ -n "$claim_proxy" ]]; then
            install_options+=("--claim-proxy" "$claim_proxy")
        fi
    else
        log_info "Installing NetData without cloud integration"
    fi
    
    # Run installation
    log_info "Running NetData installer with options: ${install_options[*]}"
    if sudo bash "$installer" "${install_options[@]}"; then
        log_info "NetData installed successfully"
        rm -f "$installer"
    else
        log_error "NetData installation failed"
        rm -f "$installer"
        return 1
    fi
    
    # Wait for NetData to start
    log_info "Waiting for NetData to start..."
    local timeout=30
    while [[ $timeout -gt 0 ]]; do
        if systemctl is-active --quiet netdata; then
            log_info "NetData service is running"
            break
        fi
        sleep 2
        ((timeout -= 2))
    done
    
    if [[ $timeout -eq 0 ]]; then
        log_warn "NetData service may not have started properly"
    fi
    
    return 0
}

# Configure NetData settings
configure_netdata() {
    local enable_web="${1:-true}"
    local web_port="${2:-$NETDATA_PORT}"
    local bind_to="${3:-*}"
    local enable_streaming="${4:-false}"
    local api_key="${5:-}"
    
    log_info "Configuring NetData settings"
    
    # Backup original configuration
    if [[ -f "$NETDATA_CONFIG_DIR/netdata.conf" ]]; then
        backup_file "$NETDATA_CONFIG_DIR/netdata.conf"
    fi
    
    # Generate NetData configuration
    log_info "Generating NetData configuration"
    sudo "$NETDATA_CONFIG_DIR/../usr/libexec/netdata/netdata.conf.installer" \
        --config-dir="$NETDATA_CONFIG_DIR" \
        --stock-config-dir="$NETDATA_CONFIG_DIR" \
        --user="$NETDATA_USER" \
        --web-user="$NETDATA_USER" \
        --web-group="$NETDATA_USER" 2>/dev/null || true
    
    # Create custom configuration
    cat > /tmp/netdata.conf << EOF
# NetData Configuration - Generated by Flux
# $(date)

[global]
    # Run as user
    run as user = $NETDATA_USER
    
    # Web settings
    default port = $web_port
    bind socket to IP = $bind_to
    
    # Performance settings
    memory mode = save
    update every = 1
    history = 3600
    
    # Error log
    error log = $NETDATA_LOG_DIR/error.log
    debug log = $NETDATA_LOG_DIR/debug.log
    access log = $NETDATA_LOG_DIR/access.log

[web]
    web files owner = root
    web files group = $NETDATA_USER
    web files mode = 0640
    
    # Security settings
    respect do not track policy = yes
    allow connections from = localhost *
    allow dashboard from = localhost *
    allow badges from = *
    allow streaming from = localhost *
    allow netdata.conf from = localhost *
    allow management from = localhost

[plugins]
    # Enable/disable plugins
    proc = yes
    diskspace = yes
    cgroups = yes
    tc = no
    idlejitter = yes
    apps = yes
    python.d = yes
    charts.d = yes
    node.d = yes
    go.d = yes

[health]
    enabled = yes
    in memory max health log entries = 1000
    script to execute on alarm = $NETDATA_CONFIG_DIR/health_alarm_notify.sh
    
EOF

    # Add streaming configuration if enabled
    if [[ "$enable_streaming" == "true" && -n "$api_key" ]]; then
        cat >> /tmp/netdata.conf << EOF

[stream]
    enabled = yes
    api key = $api_key
    timeout seconds = 60
    default history = 3600
    default memory mode = save
    health enabled by default = auto
    allow from = *
    
EOF
        log_info "Streaming configuration added"
    fi
    
    # Apply configuration
    sudo mv /tmp/netdata.conf "$NETDATA_CONFIG_DIR/netdata.conf"
    sudo chown root:$NETDATA_USER "$NETDATA_CONFIG_DIR/netdata.conf"
    sudo chmod 640 "$NETDATA_CONFIG_DIR/netdata.conf"
    
    log_info "NetData configuration applied"
}

# Configure NetData health monitoring
configure_health_monitoring() {
    local notification_method="${1:-email}"
    local alert_recipients="${2:-root}"
    local discord_webhook="${3:-}"
    local slack_webhook="${4:-}"
    
    log_info "Configuring NetData health monitoring"
    
    # Backup original health configuration
    if [[ -f "$NETDATA_CONFIG_DIR/health_alarm_notify.conf" ]]; then
        backup_file "$NETDATA_CONFIG_DIR/health_alarm_notify.conf"
    fi
    
    # Create health alarm notification configuration
    cat > /tmp/health_alarm_notify.conf << EOF
# NetData Health Alarm Notification Configuration
# Generated by Flux - $(date)

# Default notification settings
DEFAULT_RECIPIENT_EMAIL="$alert_recipients"
DEFAULT_RECIPIENT_DISCORD=""
DEFAULT_RECIPIENT_SLACK=""

# Email notifications
SEND_EMAIL="YES"
EMAIL_SENDER=""
DEFAULT_RECIPIENT_EMAIL="$alert_recipients"

# Discord notifications
SEND_DISCORD="NO"
DISCORD_WEBHOOK_URL=""
DEFAULT_RECIPIENT_DISCORD=""

# Slack notifications  
SEND_SLACK="NO"
SLACK_WEBHOOK_URL=""
DEFAULT_RECIPIENT_SLACK=""

# System notifications
SEND_SYSLOG="YES"

# Custom notification script
SEND_CUSTOM="NO"
CUSTOM_SENDER=""

EOF

    # Configure specific notification methods
    case "$notification_method" in
        email)
            sed -i 's/SEND_EMAIL="NO"/SEND_EMAIL="YES"/' /tmp/health_alarm_notify.conf
            ;;
        discord)
            if [[ -n "$discord_webhook" ]]; then
                sed -i 's/SEND_DISCORD="NO"/SEND_DISCORD="YES"/' /tmp/health_alarm_notify.conf
                sed -i "s|DISCORD_WEBHOOK_URL=\"\"|DISCORD_WEBHOOK_URL=\"$discord_webhook\"|" /tmp/health_alarm_notify.conf
                sed -i "s/DEFAULT_RECIPIENT_DISCORD=\"\"/DEFAULT_RECIPIENT_DISCORD=\"$alert_recipients\"/" /tmp/health_alarm_notify.conf
            fi
            ;;
        slack)
            if [[ -n "$slack_webhook" ]]; then
                sed -i 's/SEND_SLACK="NO"/SEND_SLACK="YES"/' /tmp/health_alarm_notify.conf
                sed -i "s|SLACK_WEBHOOK_URL=\"\"|SLACK_WEBHOOK_URL=\"$slack_webhook\"|" /tmp/health_alarm_notify.conf
                sed -i "s/DEFAULT_RECIPIENT_SLACK=\"\"/DEFAULT_RECIPIENT_SLACK=\"$alert_recipients\"/" /tmp/health_alarm_notify.conf
            fi
            ;;
    esac
    
    # Apply health configuration
    sudo mv /tmp/health_alarm_notify.conf "$NETDATA_CONFIG_DIR/health_alarm_notify.conf"
    sudo chown root:$NETDATA_USER "$NETDATA_CONFIG_DIR/health_alarm_notify.conf"
    sudo chmod 640 "$NETDATA_CONFIG_DIR/health_alarm_notify.conf"
    
    # Create custom health checks
    create_custom_health_checks
    
    log_info "Health monitoring configuration completed"
}

# Create custom health checks
create_custom_health_checks() {
    log_info "Creating custom health checks"
    
    local health_dir="$NETDATA_CONFIG_DIR/health.d"
    sudo mkdir -p "$health_dir"
    
    # CPU usage alert
    cat > /tmp/cpu_usage.conf << 'EOF'
# CPU Usage Monitoring
template: cpu_usage_high
      on: system.cpu
   class: System
    type: Utilization
component: CPU
    calc: $user + $system + $nice + $iowait
    units: %
    every: 10s
     warn: $this > 80
     crit: $this > 95
     info: CPU utilization is high
       to: sysadmin

EOF
    
    # Memory usage alert
    cat > /tmp/memory_usage.conf << 'EOF'
# Memory Usage Monitoring
template: memory_usage_high
      on: system.ram
   class: System
    type: Utilization
component: Memory
    calc: ($used + $buffers + $cached) * 100 / ($used + $free + $buffers + $cached)
    units: %
    every: 10s
     warn: $this > 80
     crit: $this > 95
     info: Memory utilization is high
       to: sysadmin

EOF
    
    # Disk space alert
    cat > /tmp/disk_space.conf << 'EOF'
# Disk Space Monitoring
template: disk_space_usage
      on: disk_space._
   class: System
    type: Utilization
component: Disk
    calc: $used * 100 / ($avail + $used)
    units: %
    every: 1m
     warn: $this > 80
     crit: $this > 95
     info: Disk space utilization is high
       to: sysadmin

EOF
    
    # Load average alert
    cat > /tmp/load_average.conf << 'EOF'
# Load Average Monitoring
template: load_average_high
      on: system.load
   class: System
    type: Utilization
component: Load
    calc: $load1
    units: load
    every: 10s
     warn: $this > (($system.cpu.processors) * 1.5)
     crit: $this > (($system.cpu.processors) * 2.0)
     info: System load average is high
       to: sysadmin

EOF
    
    # Apply custom health checks
    local health_files=("cpu_usage.conf" "memory_usage.conf" "disk_space.conf" "load_average.conf")
    for health_file in "${health_files[@]}"; do
        sudo mv "/tmp/$health_file" "$health_dir/$health_file"
        sudo chown root:$NETDATA_USER "$health_dir/$health_file"
        sudo chmod 640 "$health_dir/$health_file"
        log_info "Created health check: $health_file"
    done
}

# Configure firewall for NetData
configure_firewall() {
    local allow_external="${1:-false}"
    local allowed_ips="${2:-}"
    
    log_info "Configuring firewall for NetData"
    
    # Check which firewall is in use
    if command -v ufw >/dev/null 2>&1; then
        configure_ufw_netdata "$allow_external" "$allowed_ips"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        configure_firewalld_netdata "$allow_external" "$allowed_ips"
    else
        log_warn "No supported firewall found (ufw or firewalld)"
        return 1
    fi
}

# Configure UFW for NetData
configure_ufw_netdata() {
    local allow_external="$1"
    local allowed_ips="$2"
    
    log_info "Configuring UFW for NetData"
    
    if [[ "$allow_external" == "true" ]]; then
        if [[ -n "$allowed_ips" ]]; then
            # Allow specific IPs only
            IFS=',' read -ra IPS <<< "$allowed_ips"
            for ip in "${IPS[@]}"; do
                ip=$(echo "$ip" | xargs)  # Trim whitespace
                if validate_ip "$ip" || [[ "$ip" == *"/"* ]]; then
                    sudo ufw allow from "$ip" to any port "$NETDATA_PORT"
                    log_info "Allowed NetData access from: $ip"
                fi
            done
        else
            # Allow from anywhere (not recommended for production)
            if prompt_yes_no "Allow NetData access from anywhere? (Security risk)" "n"; then
                sudo ufw allow "$NETDATA_PORT"/tcp
                log_warn "NetData access allowed from anywhere"
            fi
        fi
    else
        # Allow localhost only (default)
        sudo ufw allow from 127.0.0.1 to any port "$NETDATA_PORT"
        log_info "NetData access restricted to localhost"
    fi
}

# Configure firewalld for NetData
configure_firewalld_netdata() {
    local allow_external="$1"
    local allowed_ips="$2"
    
    log_info "Configuring firewalld for NetData"
    
    if [[ "$allow_external" == "true" ]]; then
        if [[ -n "$allowed_ips" ]]; then
            # Create rich rules for specific IPs
            IFS=',' read -ra IPS <<< "$allowed_ips"
            for ip in "${IPS[@]}"; do
                ip=$(echo "$ip" | xargs)  # Trim whitespace
                if validate_ip "$ip" || [[ "$ip" == *"/"* ]]; then
                    sudo firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$ip' port protocol='tcp' port='$NETDATA_PORT' accept"
                    log_info "Allowed NetData access from: $ip"
                fi
            done
        else
            # Allow from anywhere
            if prompt_yes_no "Allow NetData access from anywhere? (Security risk)" "n"; then
                sudo firewall-cmd --permanent --add-port="$NETDATA_PORT"/tcp
                log_warn "NetData access allowed from anywhere"
            fi
        fi
        
        # Reload firewall
        sudo firewall-cmd --reload
    else
        log_info "NetData access restricted to localhost (firewalld default)"
    fi
}

# Setup NetData SSL/TLS
setup_netdata_ssl() {
    local cert_path="${1:-}"
    local key_path="${2:-}"
    local generate_self_signed="${3:-false}"
    
    log_info "Setting up NetData SSL/TLS"
    
    local ssl_dir="$NETDATA_CONFIG_DIR/ssl"
    sudo mkdir -p "$ssl_dir"
    
    if [[ "$generate_self_signed" == "true" ]] || [[ -z "$cert_path" ]]; then
        log_info "Generating self-signed SSL certificate"
        
        # Generate self-signed certificate
        sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$ssl_dir/netdata-selfsigned.key" \
            -out "$ssl_dir/netdata-selfsigned.crt" \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=$(hostname -f)" 2>/dev/null
        
        cert_path="$ssl_dir/netdata-selfsigned.crt"
        key_path="$ssl_dir/netdata-selfsigned.key"
        
        log_info "Self-signed certificate generated"
    elif [[ -n "$cert_path" && -n "$key_path" ]]; then
        # Copy provided certificates
        if [[ -f "$cert_path" && -f "$key_path" ]]; then
            sudo cp "$cert_path" "$ssl_dir/netdata.crt"
            sudo cp "$key_path" "$ssl_dir/netdata.key"
            cert_path="$ssl_dir/netdata.crt"
            key_path="$ssl_dir/netdata.key"
            log_info "SSL certificates copied"
        else
            log_error "SSL certificate files not found"
            return 1
        fi
    fi
    
    # Set proper permissions
    sudo chown root:$NETDATA_USER "$ssl_dir"/*
    sudo chmod 640 "$ssl_dir"/*
    
    # Update NetData configuration for SSL
    cat >> /tmp/ssl_config << EOF

[web]
    ssl key = $key_path
    ssl certificate = $cert_path
    
EOF
    
    sudo tee -a "$NETDATA_CONFIG_DIR/netdata.conf" < /tmp/ssl_config > /dev/null
    rm -f /tmp/ssl_config
    
    log_info "SSL configuration added to NetData"
    log_warn "Note: You'll need to restart NetData to enable SSL"
}

# =============================================================================
# MAIN NETDATA FUNCTIONS
# =============================================================================

# Complete NetData installation and setup
full_netdata_setup() {
    local claim_token="${1:-}"
    local claim_rooms="${2:-$DEFAULT_CLAIM_ROOMS}"
    local enable_ssl="${3:-false}"
    local allow_external="${4:-false}"
    local allowed_ips="${5:-}"
    local notification_method="${6:-email}"
    local alert_recipients="${7:-root}"
    
    log_info "Starting complete NetData setup"
    
    # Check system requirements
    if ! check_netdata_requirements; then
        log_error "System requirements check failed"
        return 1
    fi
    
    # Install NetData
    if ! install_netdata "$claim_token" "$claim_rooms"; then
        log_error "NetData installation failed"
        return 1
    fi
    
    # Configure NetData
    if ! configure_netdata; then
        log_error "NetData configuration failed"
        return 1
    fi
    
    # Setup health monitoring
    if ! configure_health_monitoring "$notification_method" "$alert_recipients"; then
        log_warn "Health monitoring setup encountered issues"
    fi
    
    # Configure firewall
    if ! configure_firewall "$allow_external" "$allowed_ips"; then
        log_warn "Firewall configuration failed"
    fi
    
    # Setup SSL if requested
    if [[ "$enable_ssl" == "true" ]]; then
        setup_netdata_ssl "" "" "true"
    fi
    
    # Restart NetData to apply all configurations
    log_info "Restarting NetData service"
    if sudo systemctl restart netdata; then
        log_info "NetData service restarted successfully"
    else
        log_error "Failed to restart NetData service"
        return 1
    fi
    
    # Wait for service to be ready
    sleep 5
    
    # Verify installation
    if systemctl is-active --quiet netdata; then
        log_info "NetData service is running"
        
        # Get system IP for access information
        local system_ip=$(hostname -I | awk '{print $1}')
        local protocol="http"
        if [[ "$enable_ssl" == "true" ]]; then
            protocol="https"
        fi
        
        echo -e "\n${CYAN}=== NetData Setup Summary ===${NC}"
        echo -e "${WHITE}✓ NetData installed and configured${NC}"
        echo -e "${WHITE}✓ Health monitoring enabled${NC}"
        echo -e "${WHITE}✓ Custom health checks created${NC}"
        
        if [[ "$allow_external" == "true" ]]; then
            echo -e "${WHITE}✓ Firewall configured for external access${NC}"
        else
            echo -e "${WHITE}✓ Access restricted to localhost${NC}"
        fi
        
        if [[ "$enable_ssl" == "true" ]]; then
            echo -e "${WHITE}✓ SSL/TLS enabled${NC}"
        fi
        
        echo -e "\n${GREEN}NetData setup completed successfully!${NC}"
        echo -e "${YELLOW}Access NetData at: $protocol://localhost:$NETDATA_PORT${NC}"
        
        if [[ "$allow_external" == "true" ]]; then
            echo -e "${YELLOW}External access: $protocol://$system_ip:$NETDATA_PORT${NC}"
        fi
        
        if [[ -n "$claim_token" ]]; then
            echo -e "${YELLOW}Check NetData Cloud for your claimed node${NC}"
        fi
        
    else
        log_error "NetData service is not running"
        return 1
    fi
    
    return 0
}

# Uninstall NetData
uninstall_netdata() {
    log_warn "Starting NetData uninstallation"
    
    if ! prompt_yes_no "Are you sure you want to uninstall NetData?" "n"; then
        log_info "NetData uninstallation cancelled"
        return 0
    fi
    
    # Stop NetData service
    if systemctl is-active --quiet netdata; then
        log_info "Stopping NetData service"
        sudo systemctl stop netdata
        sudo systemctl disable netdata
    fi
    
    # Run NetData uninstaller if available
    if [[ -f "/usr/libexec/netdata/netdata-uninstaller.sh" ]]; then
        log_info "Running NetData uninstaller"
        sudo /usr/libexec/netdata/netdata-uninstaller.sh --yes --force
    elif [[ -f "/opt/netdata/usr/libexec/netdata/netdata-uninstaller.sh" ]]; then
        log_info "Running NetData uninstaller"
        sudo /opt/netdata/usr/libexec/netdata/netdata-uninstaller.sh --yes --force
    else
        log_warn "NetData uninstaller not found, performing manual cleanup"
        
        # Manual cleanup
        sudo rm -rf /opt/netdata
        sudo rm -rf /etc/netdata
        sudo rm -rf /usr/share/netdata
        sudo rm -rf /var/lib/netdata
        sudo rm -rf /var/cache/netdata
        sudo rm -rf /var/log/netdata
        sudo rm -f /etc/systemd/system/netdata.service
        sudo rm -f /usr/lib/systemd/system/netdata.service
        
        # Remove user and group
        sudo userdel netdata 2>/dev/null || true
        sudo groupdel netdata 2>/dev/null || true
    fi
    
    # Remove firewall rules
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw delete allow "$NETDATA_PORT"/tcp 2>/dev/null || true
    elif command -v firewall-cmd >/dev/null 2>&1; then
        sudo firewall-cmd --permanent --remove-port="$NETDATA_PORT"/tcp 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
    fi
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    log_info "NetData uninstallation completed"
}

# Update NetData
update_netdata() {
    log_info "Updating NetData"
    
    if [[ -f "/usr/libexec/netdata/netdata-updater.sh" ]]; then
        log_info "Running NetData updater"
        sudo /usr/libexec/netdata/netdata-updater.sh
    elif [[ -f "/opt/netdata/usr/libexec/netdata/netdata-updater.sh" ]]; then
        log_info "Running NetData updater"
        sudo /opt/netdata/usr/libexec/netdata/netdata-updater.sh
    else
        log_warn "NetData updater not found, trying reinstallation"
        
        # Download and run installer with update flag
        local installer
        if installer=$(download_netdata_installer); then
            sudo bash "$installer" --dont-wait --disable-telemetry
            rm -f "$installer"
        else
            log_error "Failed to update NetData"
            return 1
        fi
    fi
    
    log_info "NetData update completed"
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

usage() {
    cat << EOF
Usage: $0 [options]

NetData monitoring system installation and configuration module.

Options:
    -h, --help              Display this help message
    -i, --install           Install NetData (default action)
    -c, --claim TOKEN       NetData Cloud claim token
    -r, --rooms ROOMS       NetData Cloud rooms (default: $DEFAULT_CLAIM_ROOMS)
    -s, --ssl               Enable SSL/TLS with self-signed certificate
    -e, --external          Allow external access (configure firewall)
    --allowed-ips IPS       Comma-separated list of allowed IP addresses
    --notification METHOD   Notification method (email|discord|slack)
    --recipients EMAIL      Alert recipients email addresses
    --discord-webhook URL   Discord webhook URL for notifications
    --slack-webhook URL     Slack webhook URL for notifications
    -u, --update            Update NetData
    --uninstall             Uninstall NetData
    --status                Show NetData status

Examples:
    $0                                          # Install with defaults
    $0 -c "your-claim-token"                   # Install with cloud integration
    $0 -s -e --allowed-ips "10.0.1.0/24"     # Install with SSL and restricted access
    $0 --notification discord --discord-webhook "https://..." # Setup Discord alerts
    $0 -u                                      # Update NetData
    $0 --uninstall                            # Remove NetData

EOF
    exit 0
}

# Show NetData status
show_netdata_status() {
    echo -e "${CYAN}=== NetData Status ===${NC}"
    
    # Service status
    if systemctl is-active --quiet netdata; then
        echo -e "${GREEN}✓ Service: Running${NC}"
        echo "  Uptime: $(systemctl show netdata --property=ActiveEnterTimestamp --value | xargs)"
    else
        echo -e "${RED}✗ Service: Not running${NC}"
    fi
    
    # Port status
    if netstat -tuln 2>/dev/null | grep -q ":$NETDATA_PORT "; then
        echo -e "${GREEN}✓ Port $NETDATA_PORT: Listening${NC}"
    else
        echo -e "${RED}✗ Port $NETDATA_PORT: Not listening${NC}"
    fi
    
    # Configuration
    if [[ -f "$NETDATA_CONFIG_DIR/netdata.conf" ]]; then
        echo -e "${GREEN}✓ Configuration: Present${NC}"
        echo "  Config file: $NETDATA_CONFIG_DIR/netdata.conf"
    else
        echo -e "${YELLOW}⚠ Configuration: Using defaults${NC}"
    fi
    
    # Web access
    local system_ip=$(hostname -I | awk '{print $1}')
    echo -e "${WHITE}Web Interface:${NC}"
    echo "  Local: http://localhost:$NETDATA_PORT"
    echo "  Network: http://$system_ip:$NETDATA_PORT"
    
    # Log files
    if [[ -d "$NETDATA_LOG_DIR" ]]; then
        echo -e "${WHITE}Log files:${NC}"
        ls -la "$NETDATA_LOG_DIR" 2>/dev/null || echo "  No log files found"
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local install_mode=true
    local claim_token=""
    local claim_rooms="$DEFAULT_CLAIM_ROOMS"
    local enable_ssl=false
    local allow_external=false
    local allowed_ips=""
    local notification_method="email"
    local alert_recipients="root"
    local discord_webhook=""
    local slack_webhook=""
    local update_mode=false
    local uninstall_mode=false
    local status_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -i|--install)
                install_mode=true
                shift
                ;;
            -c|--claim)
                claim_token="$2"
                shift 2
                ;;
            -r|--rooms)
                claim_rooms="$2"
                shift 2
                ;;
            -s|--ssl)
                enable_ssl=true
                shift
                ;;
            -e|--external)
                allow_external=true
                shift
                ;;
            --allowed-ips)
                allowed_ips="$2"
                shift 2
                ;;
            --notification)
                notification_method="$2"
                shift 2
                ;;
            --recipients)
                alert_recipients="$2"
                shift 2
                ;;
            --discord-webhook)
                discord_webhook="$2"
                notification_method="discord"
                shift 2
                ;;
            --slack-webhook)
                slack_webhook="$2"
                notification_method="slack"
                shift 2
                ;;
            -u|--update)
                update_mode=true
                install_mode=false
                shift
                ;;
            --uninstall)
                uninstall_mode=true
                install_mode=false
                shift
                ;;
            --status)
                status_mode=true
                install_mode=false
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    log_info "Flux NetData module started"
    
    # Handle specific modes
    if [[ "$status_mode" == true ]]; then
        show_netdata_status
        exit $?
    fi
    
    if [[ "$update_mode" == true ]]; then
        update_netdata
        exit $?
    fi
    
    if [[ "$uninstall_mode" == true ]]; then
        uninstall_netdata
        exit $?
    fi
    
    if [[ "$install_mode" == true ]]; then
        # Set webhook URLs for notification methods
        case "$notification_method" in
            discord)
                if [[ -z "$discord_webhook" ]]; then
                    read -p "Enter Discord webhook URL: " discord_webhook
                fi
                ;;
            slack)
                if [[ -z "$slack_webhook" ]]; then
                    read -p "Enter Slack webhook URL: " slack_webhook
                fi
                ;;
        esac
        
        full_netdata_setup "$claim_token" "$claim_rooms" "$enable_ssl" "$allow_external" "$allowed_ips" "$notification_method" "$alert_recipients"
        exit $?
    fi
    
    # Default action is install
    full_netdata_setup "$claim_token" "$claim_rooms" "$enable_ssl" "$allow_external" "$allowed_ips" "$notification_method" "$alert_recipients"
}

# Run main function with all arguments
main "$@"