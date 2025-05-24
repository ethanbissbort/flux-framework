#!/bin/bash

# flux-motd.sh - Custom MOTD (Message of the Day) setup module
# Creates custom login messages with ASCII art and system information

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

# MOTD directories and files
readonly MOTD_FILE="/etc/motd"
readonly MOTD_DIR="/etc/update-motd.d"
readonly MOTD_BACKUP_DIR="/etc/motd-backup"

# Default ASCII art
readonly DEFAULT_ASCII_ART='
 ███████╗██╗     ██╗   ██╗██╗  ██╗
 ██╔════╝██║     ██║   ██║╚██╗██╔╝
 █████╗  ██║     ██║   ██║ ╚███╔╝ 
 ██╔══╝  ██║     ██║   ██║ ██╔██╗ 
 ██║     ███████╗╚██████╔╝██╔╝ ██╗
 ╚═╝     ╚══════╝ ╚═════╝ ╚═╝  ╚═╝

    Welcome to Flux System
    Configured with Flux Scripts
'

# Color codes for MOTD
readonly MOTD_COLORS=(
    '\033[0;31m'  # Red
    '\033[0;32m'  # Green
    '\033[0;33m'  # Yellow
    '\033[0;34m'  # Blue
    '\033[0;35m'  # Purple
    '\033[0;36m'  # Cyan
    '\033[1;37m'  # White
    '\033[0m'     # Reset
)

# =============================================================================
# MOTD CREATION FUNCTIONS
# =============================================================================

# Create ASCII art header
create_ascii_header() {
    local art_source="${1:-default}"
    local color_code="${2:-\033[0;36m}"  # Default cyan
    
    log_info "Creating ASCII art header"
    
    local ascii_content=""
    
    case "$art_source" in
        "default")
            ascii_content="$DEFAULT_ASCII_ART"
            ;;
        "flux-large")
            ascii_content='
██████╗ ██╗     ██╗   ██╗██╗  ██╗    ██╗      █████╗ ██████╗ 
██╔══██╗██║     ██║   ██║╚██╗██╔╝    ██║     ██╔══██╗██╔══██╗
██████╔╝██║     ██║   ██║ ╚███╔╝     ██║     ███████║██████╔╝
██╔══██╗██║     ██║   ██║ ██╔██╗     ██║     ██╔══██║██╔══██╗
██║  ██║███████╗╚██████╔╝██╔╝ ██╗    ███████╗██║  ██║██████╔╝
╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝    ╚══════╝╚═╝  ╚═╝╚═════╝ 

            ⚡ Flux System Administration ⚡
'
            ;;
        "simple")
            ascii_content='
  ▄████████  ▄█       ▄████████    ▄████████    ▄████████ 
  ███    ███ ███      ███    ███   ███    ███   ███    ███ 
  ███    █▀  ███      ███    █▀    ███    █▀    ███    █▀  
 ▄███▄▄▄     ███      ███         ▄███▄▄▄      ▄███▄▄▄     
▀▀███▀▀▀     ███      ███        ▀▀███▀▀▀     ▀▀███▀▀▀     
  ███        ███      ███    █▄    ███    █▄    ███        
  ███        ███▌    ▄███    ███   ███    ███   ███        
  ███        █████▄▄ ████████▀    ██████████   ███        

        System Configuration Framework
'
            ;;
        "minimal")
            ascii_content='
┌─────────────────────────────────────┐
│              FLUX SYSTEM            │
│         Administration Panel        │
└─────────────────────────────────────┘
'
            ;;
        *)
            # Treat as URL or file path
            if [[ "$art_source" =~ ^https?:// ]]; then
                log_info "Downloading ASCII art from URL: $art_source"
                if safe_download "$art_source" "/tmp/custom_ascii"; then
                    ascii_content=$(cat /tmp/custom_ascii)
                    rm -f /tmp/custom_ascii
                else
                    log_warn "Failed to download ASCII art, using default"
                    ascii_content="$DEFAULT_ASCII_ART"
                fi
            elif [[ -f "$art_source" ]]; then
                log_info "Reading ASCII art from file: $art_source"
                ascii_content=$(cat "$art_source")
            else
                log_warn "Invalid ASCII art source, using default"
                ascii_content="$DEFAULT_ASCII_ART"
            fi
            ;;
    esac
    
    # Apply color coding
    echo -e "${color_code}${ascii_content}\033[0m"
}

# Get system information
get_system_info() {
    local show_detailed="${1:-false}"
    
    # Basic system information
    local hostname=$(hostname -f 2>/dev/null || hostname)
    local kernel=$(uname -r)
    local uptime=$(uptime -p 2>/dev/null || uptime | awk -F'( |,|:)+' '{print $6,$7",",$8,"h",$9,"m"}')
    local users=$(who | wc -l)
    local load=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    
    # Memory information
    local memory_info=$(free -h | awk 'NR==2{printf "%.1f/%.1fGB (%.0f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}' 2>/dev/null || free -m | awk 'NR==2{printf "%.1f/%.1fGB (%.0f%%)", $3/1024, $2/1024, $3*100/$2}')
    
    # Disk information
    local disk_info=$(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')
    
    # Network information
    local ip_addr=$(hostname -I | awk '{print $1}' 2>/dev/null || ip route get 1 | awk '{print $7}' | head -1)
    
    # Temperature (if available)
    local temperature=""
    if command -v sensors >/dev/null 2>&1; then
        temperature=$(sensors 2>/dev/null | grep "Core 0" | awk '{print $3}' | head -1)
    elif [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        local temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp)
        temperature="$((temp_raw/1000))°C"
    fi
    
    # Services status (if detailed)
    local services_info=""
    if [[ "$show_detailed" == "true" ]]; then
        local services=("ssh" "ufw" "fail2ban" "docker" "nginx" "apache2")
        local running_services=()
        
        for service in "${services[@]}"; do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                running_services+=("$service")
            fi
        done
        
        if [[ ${#running_services[@]} -gt 0 ]]; then
            services_info=$(IFS=", "; echo "${running_services[*]}")
        fi
    fi
    
    # Format output
    cat << EOF

System Information:
  Hostname: $hostname
  Kernel: $kernel
  Uptime: $uptime
  Users: $users logged in
  Load: $load
  Memory: $memory_info
  Disk: $disk_info
  IP Address: $ip_addr
EOF
    
    if [[ -n "$temperature" ]]; then
        echo "  Temperature: $temperature"
    fi
    
    if [[ -n "$services_info" ]]; then
        echo "  Active Services: $services_info"
    fi
    
    echo
}

# Get security status
get_security_status() {
    local security_info=""
    
    # Check firewall status
    local firewall_status="Unknown"
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            firewall_status="UFW Active"
        else
            firewall_status="UFW Inactive"
        fi
    elif command -v firewalld >/dev/null 2>&1; then
        if systemctl is-active --quiet firewalld; then
            firewall_status="Firewalld Active"
        else
            firewall_status="Firewalld Inactive"
        fi
    fi
    
    # Check fail2ban status
    local fail2ban_status="Not Installed"
    if command -v fail2ban-client >/dev/null 2>&1; then
        if systemctl is-active --quiet fail2ban; then
            local jails=$(fail2ban-client status 2>/dev/null | grep "Jail list" | awk -F: '{print $2}' | xargs)
            fail2ban_status="Active ($jails)"
        else
            fail2ban_status="Inactive"
        fi
    fi
    
    # Check for updates
    local updates_status=""
    local distro=$(detect_distro)
    case $distro in
        ubuntu|debian|mint|pop)
            if [[ -f /var/run/reboot-required ]]; then
                updates_status="Reboot Required"
            else
                local updates=$(apt list --upgradable 2>/dev/null | grep -v "WARNING" | wc -l)
                if [[ $updates -gt 0 ]]; then
                    updates_status="$updates updates available"
                else
                    updates_status="System up to date"
                fi
            fi
            ;;
        centos|fedora|rhel|rocky|almalinux)
            local pkg_manager="yum"
            if command -v dnf >/dev/null 2>&1; then
                pkg_manager="dnf"
            fi
            local updates=$($pkg_manager check-update 2>/dev/null | wc -l)
            if [[ $updates -gt 0 ]]; then
                updates_status="$updates updates available"
            else
                updates_status="System up to date"
            fi
            ;;
    esac
    
    cat << EOF
Security Status:
  Firewall: $firewall_status
  Fail2Ban: $fail2ban_status
  Updates: $updates_status

EOF
}

# Get last login information
get_login_info() {
    echo "Recent Logins:"
    last -n 5 | head -5 | while read line; do
        echo "  $line"
    done
    echo
}

# Create dynamic MOTD scripts
create_dynamic_motd() {
    local enable_colors="${1:-true}"
    local show_security="${2:-true}"
    local show_logins="${3:-false}"
    local show_detailed="${4:-false}"
    
    log_info "Creating dynamic MOTD scripts"
    
    # Create MOTD directory if it doesn't exist
    sudo mkdir -p "$MOTD_DIR"
    
    # Disable default Ubuntu MOTD scripts
    disable_default_motd
    
    # Create main system info script
    cat > /tmp/10-flux-header << 'EOF'
#!/bin/bash
# Flux MOTD Header Script

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Display header with timestamp
echo -e "${CYAN}"
cat /etc/motd 2>/dev/null || echo "Flux System"
echo -e "${NC}"
echo -e "${WHITE}Last update: $(date)${NC}"
echo
EOF
    
    sudo mv /tmp/10-flux-header "$MOTD_DIR/10-flux-header"
    sudo chmod +x "$MOTD_DIR/10-flux-header"
    
    # Create system information script
    cat > /tmp/20-flux-sysinfo << EOF
#!/bin/bash
# Flux System Information Script

# Function to get system info
show_system_info() {
    local hostname=\$(hostname -f 2>/dev/null || hostname)
    local kernel=\$(uname -r)
    local uptime=\$(uptime -p 2>/dev/null || uptime | awk -F'( |,|:)+' '{print \$6,\$7",",\$8,"h",\$9,"m"}')
    local users=\$(who | wc -l)
    local load=\$(cat /proc/loadavg | awk '{print \$1, \$2, \$3}')
    local memory=\$(free -h | awk 'NR==2{printf "%.1f/%.1fGB (%.0f%%)", \$3/1024/1024, \$2/1024/1024, \$3*100/\$2}' 2>/dev/null || free -m | awk 'NR==2{printf "%.1f/%.1fGB (%.0f%%)", \$3/1024, \$2/1024, \$3*100/\$2}')
    local disk=\$(df -h / | awk 'NR==2{printf "%s/%s (%s)", \$3, \$2, \$5}')
    local ip=\$(hostname -I | awk '{print \$1}' 2>/dev/null || ip route get 1 | awk '{print \$7}' | head -1)
    
    echo "System Information:"
    echo "  Hostname: \$hostname"
    echo "  Kernel: \$kernel"
    echo "  Uptime: \$uptime"
    echo "  Users: \$users logged in"
    echo "  Load: \$load"
    echo "  Memory: \$memory"
    echo "  Disk: \$disk"
    echo "  IP Address: \$ip"
    
    # Temperature if available
    if command -v sensors >/dev/null 2>&1; then
        local temp=\$(sensors 2>/dev/null | grep "Core 0" | awk '{print \$3}' | head -1)
        if [[ -n "\$temp" ]]; then
            echo "  Temperature: \$temp"
        fi
    elif [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        local temp_raw=\$(cat /sys/class/thermal/thermal_zone0/temp)
        local temp="\$((temp_raw/1000))°C"
        echo "  Temperature: \$temp"
    fi
    
    echo
}

show_system_info
EOF
    
    sudo mv /tmp/20-flux-sysinfo "$MOTD_DIR/20-flux-sysinfo"
    sudo chmod +x "$MOTD_DIR/20-flux-sysinfo"
    
    # Create security status script (if enabled)
    if [[ "$show_security" == "true" ]]; then
        cat > /tmp/30-flux-security << 'EOF'
#!/bin/bash
# Flux Security Status Script

show_security_status() {
    # Firewall status
    local firewall_status="Unknown"
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            firewall_status="UFW Active"
        else
            firewall_status="UFW Inactive"
        fi
    elif command -v firewalld >/dev/null 2>&1; then
        if systemctl is-active --quiet firewalld; then
            firewall_status="Firewalld Active"
        else
            firewall_status="Firewalld Inactive"
        fi
    fi
    
    # Fail2ban status
    local fail2ban_status="Not Installed"
    if command -v fail2ban-client >/dev/null 2>&1; then
        if systemctl is-active --quiet fail2ban; then
            fail2ban_status="Active"
        else
            fail2ban_status="Inactive"
        fi
    fi
    
    echo "Security Status:"
    echo "  Firewall: $firewall_status"
    echo "  Fail2Ban: $fail2ban_status"
    echo
}

show_security_status
EOF
        
        sudo mv /tmp/30-flux-security "$MOTD_DIR/30-flux-security"
        sudo chmod +x "$MOTD_DIR/30-flux-security"
    fi
    
    # Create login information script (if enabled)
    if [[ "$show_logins" == "true" ]]; then
        cat > /tmp/40-flux-logins << 'EOF'
#!/bin/bash
# Flux Login Information Script

show_login_info() {
    echo "Recent Logins:"
    last -n 3 | head -3 | while read line; do
        echo "  $line"
    done
    echo
}

show_login_info
EOF
        
        sudo mv /tmp/40-flux-logins "$MOTD_DIR/40-flux-logins"
        sudo chmod +x "$MOTD_DIR/40-flux-logins"
    fi
    
    # Create footer script
    cat > /tmp/90-flux-footer << 'EOF'
#!/bin/bash
# Flux MOTD Footer Script

echo "For system help, run: flux-help"
echo "For Flux commands, run: flux-commands"
echo
EOF
    
    sudo mv /tmp/90-flux-footer "$MOTD_DIR/90-flux-footer"
    sudo chmod +x "$MOTD_DIR/90-flux-footer"
    
    log_info "Dynamic MOTD scripts created successfully"
}

# Disable default MOTD scripts
disable_default_motd() {
    log_info "Disabling default MOTD scripts"
    
    # List of default Ubuntu MOTD scripts to disable
    local default_scripts=(
        "10-help-text"
        "50-motd-news"
        "80-esm"
        "90-updates-available"
        "95-hwe-eol"
    )
    
    for script in "${default_scripts[@]}"; do
        local script_path="$MOTD_DIR/$script"
        if [[ -f "$script_path" ]]; then
            log_info "Disabling default script: $script"
            sudo chmod -x "$script_path" 2>/dev/null || true
        fi
    done
    
    # Disable MOTD news
    if [[ -f /etc/default/motd-news ]]; then
        sudo sed -i 's/ENABLED=1/ENABLED=0/' /etc/default/motd-news
    fi
}

# Create custom MOTD banner
create_custom_banner() {
    local ascii_source="${1:-default}"
    local color="${2:-cyan}"
    local organization="${3:-}"
    local custom_message="${4:-}"
    
    log_info "Creating custom MOTD banner"
    
    # Map color names to codes
    local color_code='\033[0;36m'  # Default cyan
    case "$color" in
        red) color_code='\033[0;31m' ;;
        green) color_code='\033[0;32m' ;;
        yellow) color_code='\033[1;33m' ;;
        blue) color_code='\033[0;34m' ;;
        purple) color_code='\033[0;35m' ;;
        cyan) color_code='\033[0;36m' ;;
        white) color_code='\033[1;37m' ;;
    esac
    
    # Create the banner content
    local banner_content=""
    banner_content=$(create_ascii_header "$ascii_source" "$color_code")
    
    # Add organization info if provided
    if [[ -n "$organization" ]]; then
        banner_content+="\n\033[1;37m    $organization\033[0m\n"
    fi
    
    # Add custom message if provided
    if [[ -n "$custom_message" ]]; then
        banner_content+="\n\033[0;33m    $custom_message\033[0m\n"
    fi
    
    # Write to MOTD file
    echo -e "$banner_content" | sudo tee "$MOTD_FILE" > /dev/null
    
    log_info "Custom MOTD banner created"
}

# Backup existing MOTD configuration
backup_motd_config() {
    log_info "Backing up existing MOTD configuration"
    
    local backup_dir="$MOTD_BACKUP_DIR/$(date +%Y%m%d_%H%M%S)"
    sudo mkdir -p "$backup_dir"
    
    # Backup main MOTD file
    if [[ -f "$MOTD_FILE" ]]; then
        sudo cp "$MOTD_FILE" "$backup_dir/"
        log_info "Backed up: $MOTD_FILE"
    fi
    
    # Backup MOTD scripts directory
    if [[ -d "$MOTD_DIR" ]]; then
        sudo cp -r "$MOTD_DIR" "$backup_dir/"
        log_info "Backed up: $MOTD_DIR"
    fi
    
    # Backup SSH banner if it exists
    if [[ -f "/etc/ssh/banner" ]]; then
        sudo cp "/etc/ssh/banner" "$backup_dir/"
        log_info "Backed up: SSH banner"
    fi
    
    log_info "MOTD configuration backed up to: $backup_dir"
    echo "$backup_dir"
}

# Create SSH banner
create_ssh_banner() {
    local banner_text="${1:-Welcome to Flux System}"
    
    log_info "Creating SSH banner"
    
    cat > /tmp/ssh_banner << EOF
================================================================================
                              AUTHORIZED ACCESS ONLY
================================================================================

$banner_text

This system is for authorized users only. All activities are monitored and
logged. Unauthorized access is prohibited and will be prosecuted to the
full extent of the law.

By accessing this system, you consent to monitoring and acknowledge that
there is no expectation of privacy.

================================================================================
EOF
    
    sudo mv /tmp/ssh_banner /etc/ssh/banner
    sudo chmod 644 /etc/ssh/banner
    
    # Update SSH configuration to use banner
    if ! grep -q "Banner /etc/ssh/banner" /etc/ssh/sshd_config; then
        echo "Banner /etc/ssh/banner" | sudo tee -a /etc/ssh/sshd_config > /dev/null
        log_info "SSH banner configured in sshd_config"
        
        # Restart SSH service
        if sudo systemctl restart sshd; then
            log_info "SSH service restarted to apply banner"
        else
            log_warn "Failed to restart SSH service"
        fi
    else
        log_info "SSH banner already configured"
    fi
}

# =============================================================================
# MAIN MOTD FUNCTIONS
# =============================================================================

# Complete MOTD setup
full_motd_setup() {
    local ascii_source="${1:-default}"
    local color="${2:-cyan}"
    local organization="${3:-}"
    local custom_message="${4:-}"
    local enable_security="${5:-true}"
    local enable_logins="${6:-false}"
    local create_ssh_banner_flag="${7:-false}"
    
    log_info "Starting complete MOTD setup"
    
    # Backup existing configuration
    backup_motd_config
    
    # Create custom banner
    create_custom_banner "$ascii_source" "$color" "$organization" "$custom_message"
    
    # Create dynamic MOTD scripts
    create_dynamic_motd "true" "$enable_security" "$enable_logins" "false"
    
    # Create SSH banner if requested
    if [[ "$create_ssh_banner_flag" == "true" ]]; then
        local banner_text="$organization"
        if [[ -n "$custom_message" ]]; then
            banner_text="$custom_message"
        fi
        create_ssh_banner "$banner_text"
    fi
    
    # Test MOTD generation
    log_info "Testing MOTD generation"
    if sudo run-parts "$MOTD_DIR" > /tmp/motd_test; then
        log_info "MOTD generation test successful"
        rm -f /tmp/motd_test
    else
        log_warn "MOTD generation test failed"
    fi
    
    log_info "Complete MOTD setup finished"
    
    # Show summary
    echo -e "\n${CYAN}=== MOTD Setup Summary ===${NC}"
    echo -e "${WHITE}✓ MOTD banner created${NC}"
    echo -e "${WHITE}✓ Dynamic scripts configured${NC}"
    echo -e "${WHITE}✓ Default scripts disabled${NC}"
    
    if [[ "$create_ssh_banner_flag" == "true" ]]; then
        echo -e "${WHITE}✓ SSH banner configured${NC}"
    fi
    
    echo -e "\n${GREEN}MOTD setup completed successfully!${NC}"
    echo -e "${YELLOW}Preview your MOTD with: sudo run-parts /etc/update-motd.d/${NC}"
    
    return 0
}

# Preview MOTD
preview_motd() {
    log_info "Generating MOTD preview"
    
    echo -e "${CYAN}=== MOTD Preview ===${NC}"
    
    # Show static MOTD
    if [[ -f "$MOTD_FILE" ]]; then
        cat "$MOTD_FILE"
    fi
    
    # Show dynamic MOTD
    if [[ -d "$MOTD_DIR" ]]; then
        sudo run-parts "$MOTD_DIR"
    fi
    
    echo -e "${CYAN}=== End Preview ===${NC}"
}

# Reset MOTD to default
reset_motd() {
    log_warn "Resetting MOTD to system default"
    
    if ! prompt_yes_no "Are you sure you want to reset MOTD to default?" "n"; then
        log_info "MOTD reset cancelled"
        return 0
    fi
    
    # Backup current configuration
    backup_motd_config
    
    # Remove custom MOTD file
    if [[ -f "$MOTD_FILE" ]]; then
        sudo rm -f "$MOTD_FILE"
        log_info "Removed custom MOTD file"
    fi
    
    # Remove custom MOTD scripts
    local custom_scripts=(
        "10-flux-header"
        "20-flux-sysinfo"
        "30-flux-security"
        "40-flux-logins"
        "90-flux-footer"
    )
    
    for script in "${custom_scripts[@]}"; do
        local script_path="$MOTD_DIR/$script"
        if [[ -f "$script_path" ]]; then
            sudo rm -f "$script_path"
            log_info "Removed custom script: $script"
        fi
    done
    
    # Re-enable default scripts
    local default_scripts=(
        "10-help-text"
        "50-motd-news"
        "80-esm"
        "90-updates-available"
        "95-hwe-eol"
    )
    
    for script in "${default_scripts[@]}"; do
        local script_path="$MOTD_DIR/$script"
        if [[ -f "$script_path" ]]; then
            sudo chmod +x "$script_path"
            log_info "Re-enabled default script: $script"
        fi
    done
    
    # Re-enable MOTD news
    if [[ -f /etc/default/motd-news ]]; then
        sudo sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/motd-news
    fi
    
    # Remove SSH banner
    if [[ -f "/etc/ssh/banner" ]]; then
        sudo rm -f "/etc/ssh/banner"
        sudo sed -i '/Banner \/etc\/ssh\/banner/d' /etc/ssh/sshd_config
        sudo systemctl restart sshd
        log_info "Removed SSH banner"
    fi
    
    log_info "MOTD reset to default completed"
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

usage() {
    cat << EOF
Usage: $0 [options]

Custom MOTD (Message of the Day) setup and configuration module.

Options:
    -h, --help              Display this help message
    -s, --setup             Setup custom MOTD (default action)
    -a, --ascii SOURCE      ASCII art source (default|flux-large|simple|minimal|URL|file)
    -c, --color COLOR       Banner color (red|green|yellow|blue|purple|cyan|white)
    -o, --org TEXT          Organization name
    -m, --message TEXT      Custom welcome message
    --security              Include security status (default: enabled)
    --logins                Include login information
    --ssh-banner            Create SSH login banner
    -p, --preview           Preview current MOTD
    -r, --reset             Reset MOTD to system default
    -b, --backup            Backup current MOTD configuration

Examples:
    $0                                      # Setup with defaults
    $0 -a flux-large -c blue               # Large Flux logo in blue
    $0 -o "Acme Corp" -m "Welcome!"        # Custom organization and message
    $0 --logins --ssh-banner               # Include logins and SSH banner
    $0 -p                                  # Preview current MOTD
    $0 -r                                  # Reset to default

ASCII Sources:
    default     - Standard Flux logo
    flux-large  - Large Flux Lab logo
    simple      - Simple text banner
    minimal     - Minimal box design
    URL         - Download from URL
    file        - Read from local file

EOF
    exit 0
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local setup_mode=true
    local ascii_source="default"
    local color="cyan"
    local organization=""
    local custom_message=""
    local enable_security=true
    local enable_logins=false
    local create_ssh_banner_flag=false
    local preview_mode=false
    local reset_mode=false
    local backup_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -s|--setup)
                setup_mode=true
                shift
                ;;
            -a|--ascii)
                ascii_source="$2"
                shift 2
                ;;
            -c|--color)
                color="$2"
                shift 2
                ;;
            -o|--org)
                organization="$2"
                shift 2
                ;;
            -m|--message)
                custom_message="$2"
                shift 2
                ;;
            --security)
                enable_security=true
                shift
                ;;
            --logins)
                enable_logins=true
                shift
                ;;
            --ssh-banner)
                create_ssh_banner_flag=true
                shift
                ;;
            -p|--preview)
                preview_mode=true
                setup_mode=false
                shift
                ;;
            -r|--reset)
                reset_mode=true
                setup_mode=false
                shift
                ;;
            -b|--backup)
                backup_mode=true
                setup_mode=false
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    log_info "Flux MOTD module started"
    
    # Handle specific modes
    if [[ "$backup_mode" == true ]]; then
        backup_motd_config
        exit $?
    fi
    
    if [[ "$preview_mode" == true ]]; then
        preview_motd
        exit $?
    fi
    
    if [[ "$reset_mode" == true ]]; then
        reset_motd
        exit $?
    fi
    
    if [[ "$setup_mode" == true ]]; then
        full_motd_setup "$ascii_source" "$color" "$organization" "$custom_message" "$enable_security" "$enable_logins" "$create_ssh_banner_flag"
        exit $?
    fi
    
    # Default action is setup
    full_motd_setup "$ascii_source" "$color" "$organization" "$custom_message" "$enable_security" "$enable_logins" "$create_ssh_banner_flag"
}

# Run main function with all arguments
main "$@"