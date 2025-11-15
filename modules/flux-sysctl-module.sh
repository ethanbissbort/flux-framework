#!/bin/bash

# flux-sysctl-module.sh - Kernel parameter hardening module
# Version: 2.0.0
# Applies security-focused sysctl parameters for system hardening

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

readonly SYSCTL_CONF="/etc/sysctl.d/99-fluxsysctl.conf"
readonly SYSCTL_BACKUP_DIR="/etc/sysctl.d/backups"

# =============================================================================
# SYSCTL HARDENING FUNCTIONS
# =============================================================================

# Show current sysctl configuration
show_sysctl_config() {
    log_info "Current sysctl hardening configuration"

    if [[ -f "$SYSCTL_CONF" ]]; then
        log_info "Configuration file: $SYSCTL_CONF"
        echo
        cat "$SYSCTL_CONF"
        echo
    else
        log_warn "No flux sysctl configuration found at $SYSCTL_CONF"
    fi
}

# Apply sysctl hardening configuration
apply_sysctl_hardening() {
    local force="${1:-false}"

    print_header "Applying Sysctl Hardening"

    # Check if already configured
    if [[ -f "$SYSCTL_CONF" ]] && [[ "$force" != "true" ]]; then
        log_warn "Sysctl configuration already exists: $SYSCTL_CONF"
        if ! prompt_yes_no "Overwrite existing configuration?" "n"; then
            log_info "Keeping existing configuration"
            return 0
        fi
    fi

    # Create backup directory
    sudo mkdir -p "$SYSCTL_BACKUP_DIR" 2>/dev/null

    # Backup existing configuration if it exists
    if [[ -f "$SYSCTL_CONF" ]]; then
        local backup_file="$SYSCTL_BACKUP_DIR/99-fluxsysctl.conf.$(date +%Y%m%d_%H%M%S)"
        sudo cp "$SYSCTL_CONF" "$backup_file"
        log_info "Backed up existing configuration to: $backup_file"
    fi

    log_info "Creating sysctl hardening configuration"

    # Create sysctl configuration file
    sudo tee "$SYSCTL_CONF" > /dev/null << 'EOL'
# Flux Framework Sysctl Hardening Configuration
# This configuration applies security hardening parameters for:
# - Network security (IPv4/IPv6)
# - Kernel protection
# - File system security
# - Performance optimization

# =============================================================================
# KERNEL PARAMETERS
# =============================================================================

# Controls the System Request debugging functionality
kernel.sysrq = 0

# Controls whether core dumps will append the PID to the core filename
kernel.core_uses_pid = 1

# Reboot the machine soon after a kernel panic
kernel.panic = 10

# Addresses of mmap base, heap, stack and VDSO page are randomized
kernel.randomize_va_space = 2

# Allow for more PIDs
kernel.pid_max = 65536

# =============================================================================
# IPv4 NETWORKING
# =============================================================================

# Controls IP packet forwarding (disabled for security)
net.ipv4.ip_forward = 0

# Do not accept source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Send redirects disabled (this is not a router)
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Do not accept ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# Log packets with impossible addresses
net.ipv4.conf.all.log_martians = 1

# Enable source validation by reversed path (RFC1812)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore all ICMP ECHO and TIMESTAMP requests sent via broadcast/multicast
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bad ICMP errors
net.ipv4.icmp_ignore_bogus_error_responses = 1

# SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 5

# RFC 1337 fix
net.ipv4.tcp_rfc1337 = 1

# TCP window scaling and timestamps
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1

# TCP connection reuse and timeout
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10

# TCP keepalive settings
net.ipv4.tcp_keepalive_time = 1800
net.ipv4.tcp_keepalive_intvl = 2
net.ipv4.tcp_keepalive_probes = 2

# TCP buffer sizes (10MB)
net.core.wmem_max = 12582912
net.core.rmem_max = 12582912
net.ipv4.tcp_rmem = 10240 87380 12582912
net.ipv4.tcp_wmem = 10240 87380 12582912

# Network device backlog
net.core.netdev_max_backlog = 5000

# TCP metrics and port range
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.ip_local_port_range = 2000 65000

# BBR Congestion Control (modern TCP)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# =============================================================================
# IPv6 NETWORKING
# =============================================================================

# Router solicitations (this is not a router)
net.ipv6.conf.default.router_solicitations = 0

# Do not accept router advertisements
net.ipv6.conf.default.accept_ra_rtr_pref = 0
net.ipv6.conf.default.accept_ra_pinfo = 0
net.ipv6.conf.default.accept_ra_defrtr = 0

# Disable IPv6 autoconfiguration
net.ipv6.conf.default.autoconf = 0

# Neighbor solicitations
net.ipv6.conf.default.dad_transmits = 0

# Maximum IPv6 addresses per interface
net.ipv6.conf.default.max_addresses = 1

# =============================================================================
# FILE SYSTEM SECURITY
# =============================================================================

# Increase system file descriptor limit
fs.file-max = 65535

# Protects against creating or following links under certain conditions
fs.protected_hardlinks = 1
fs.protected_symlinks = 1

EOL

    log_success "Sysctl hardening configuration created"

    # Apply the configuration
    log_info "Applying sysctl configuration"
    if sudo sysctl -p "$SYSCTL_CONF"; then
        log_success "Sysctl hardening applied successfully"
        set_reboot_needed "Sysctl kernel parameters changed"
        return 0
    else
        log_error "Failed to apply sysctl configuration"
        return 1
    fi
}

# Remove sysctl hardening
remove_sysctl_hardening() {
    print_header "Removing Sysctl Hardening"

    if [[ ! -f "$SYSCTL_CONF" ]]; then
        log_warn "No flux sysctl configuration found"
        return 0
    fi

    if prompt_yes_no "Are you sure you want to remove sysctl hardening?" "n"; then
        # Backup before removing
        sudo mkdir -p "$SYSCTL_BACKUP_DIR"
        local backup_file="$SYSCTL_BACKUP_DIR/99-fluxsysctl.conf.removed.$(date +%Y%m%d_%H%M%S)"
        sudo mv "$SYSCTL_CONF" "$backup_file"
        log_success "Sysctl configuration removed and backed up to: $backup_file"
        log_warn "Default kernel parameters will be used after reboot"
        set_reboot_needed "Sysctl configuration removed"
        return 0
    else
        log_info "Removal cancelled"
        return 1
    fi
}

# Verify sysctl settings
verify_sysctl() {
    print_header "Verifying Sysctl Configuration"

    if [[ ! -f "$SYSCTL_CONF" ]]; then
        log_error "No flux sysctl configuration found"
        return 1
    fi

    log_info "Checking applied sysctl parameters"
    echo

    # Key parameters to verify
    local params=(
        "net.ipv4.ip_forward"
        "net.ipv4.tcp_syncookies"
        "net.ipv4.conf.all.rp_filter"
        "kernel.randomize_va_space"
        "fs.protected_hardlinks"
    )

    local all_ok=true
    for param in "${params[@]}"; do
        local current_value=$(sysctl -n "$param" 2>/dev/null)
        local config_value=$(grep "^$param" "$SYSCTL_CONF" 2>/dev/null | awk '{print $NF}')

        if [[ "$current_value" == "$config_value" ]]; then
            echo -e "${GREEN}✓${NC} $param = $current_value"
        else
            echo -e "${RED}✗${NC} $param = $current_value (configured: $config_value)"
            all_ok=false
        fi
    done

    echo
    if [[ "$all_ok" == "true" ]]; then
        log_success "All key parameters verified successfully"
        return 0
    else
        log_warn "Some parameters don't match configuration"
        log_info "Run 'sudo sysctl -p $SYSCTL_CONF' to apply or reboot the system"
        return 1
    fi
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

show_usage() {
    cat << EOF
Flux Sysctl Hardening Module

Usage: $(basename "$0") [OPTIONS]

Options:
    -h, --help              Show this help message
    -a, --apply             Apply sysctl hardening configuration
    -f, --force             Force overwrite existing configuration
    -s, --show              Show current sysctl configuration
    -v, --verify            Verify applied sysctl parameters
    -r, --remove            Remove sysctl hardening configuration

Examples:
    $(basename "$0") --apply            # Apply hardening (interactive)
    $(basename "$0") --apply --force    # Force apply (overwrite)
    $(basename "$0") --verify           # Check if settings are active
    $(basename "$0") --show             # Display current config

Notes:
    - Most changes require a system reboot to take full effect
    - Original parameters are backed up before changes
    - This module applies security-focused kernel parameters
    - BBR congestion control improves network performance

EOF
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local action="apply"
    local force="false"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -a|--apply)
                action="apply"
                shift
                ;;
            -f|--force)
                force="true"
                shift
                ;;
            -s|--show)
                action="show"
                shift
                ;;
            -v|--verify)
                action="verify"
                shift
                ;;
            -r|--remove)
                action="remove"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Execute requested action
    case "$action" in
        apply)
            apply_sysctl_hardening "$force"
            ;;
        show)
            show_sysctl_config
            ;;
        verify)
            verify_sysctl
            ;;
        remove)
            remove_sysctl_hardening
            ;;
        *)
            log_error "Unknown action: $action"
            show_usage
            exit 1
            ;;
    esac

    # Check if reboot is needed
    check_reboot_needed
}

# Run main function
main "$@"
