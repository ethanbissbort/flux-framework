#!/bin/bash

# flux-update.sh - System update and upgrade module
# Handles initial system updates, package installation, and preparation

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

# Essential packages for different distributions
readonly DEBIAN_ESSENTIAL_PACKAGES=(
    "curl"
    "wget"
    "git"
    "vim"
    "htop"
    "neofetch"
    "unzip"
    "ca-certificates"
    "gnupg"
    "lsb-release"
    "software-properties-common"
    "apt-transport-https"
    "build-essential"
    "dkms"
    "linux-headers-generic"
    "ufw"
    "fail2ban"
    "tree"
    "ncdu"
    "iotop"
    "net-tools"
    "dnsutils"
    "telnet"
    "rsync"
    "screen"
    "tmux"
    "jq"
    "dos2unix"
)

readonly REDHAT_ESSENTIAL_PACKAGES=(
    "curl"
    "wget"
    "git"
    "vim"
    "htop"
    "neofetch"
    "unzip"
    "ca-certificates"
    "gnupg2"
    "epel-release"
    "development-tools"
    "kernel-devel"
    "kernel-headers"
    "firewalld"
    "fail2ban"
    "tree"
    "ncdu"
    "iotop"
    "net-tools"
    "bind-utils"
    "telnet"
    "rsync"
    "screen"
    "tmux"
    "jq"
    "dos2unix"
)

# Development packages (optional)
readonly DEBIAN_DEV_PACKAGES=(
    "nodejs"
    "npm"
    "python3"
    "python3-pip"
    "python3-venv"
    "docker.io"
    "docker-compose"
    "ansible"
    "terraform"
)

readonly REDHAT_DEV_PACKAGES=(
    "nodejs"
    "npm"
    "python3"
    "python3-pip"
    "podman"
    "podman-compose"
    "ansible"
)

# =============================================================================
# UPDATE FUNCTIONS
# =============================================================================

# Check system requirements
check_system_requirements() {
    log_info "Checking system requirements"
    
    # Check available disk space (minimum 2GB free)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local min_space=2097152  # 2GB in KB
    
    if [[ $available_space -lt $min_space ]]; then
        log_error "Insufficient disk space. Available: $(($available_space/1024/1024))GB, Required: 2GB"
        return 1
    fi
    
    # Check memory (minimum 512MB free)
    local available_memory=$(free | awk 'NR==2{print $7}')
    local min_memory=524288  # 512MB in KB
    
    if [[ $available_memory -lt $min_memory ]]; then
        log_warn "Low memory available: $(($available_memory/1024))MB. Updates may be slow."
    fi
    
    # Check internet connectivity
    log_info "Testing internet connectivity"
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "No internet connectivity. Cannot proceed with updates."
        return 1
    fi
    
    log_info "System requirements check passed"
    return 0
}

# Update package lists
update_package_lists() {
    local distro=$(detect_distro)
    
    log_info "Updating package lists for $distro"
    
    case $distro in
        ubuntu|debian|mint|pop)
            # Update apt package lists
            if sudo apt-get update; then
                log_info "APT package lists updated successfully"
                
                # Check for broken packages
                local broken_packages=$(apt list --upgradable 2>/dev/null | grep -c "broken")
                if [[ $broken_packages -gt 0 ]]; then
                    log_warn "Found $broken_packages packages with issues"
                    if prompt_yes_no "Attempt to fix broken packages?" "y"; then
                        sudo apt-get -f install
                    fi
                fi
                
                return 0
            else
                log_error "Failed to update APT package lists"
                return 1
            fi
            ;;
        centos|fedora|rhel|rocky|almalinux)
            # Update yum/dnf package lists
            local pkg_manager="yum"
            if command -v dnf >/dev/null 2>&1; then
                pkg_manager="dnf"
            fi
            
            if sudo $pkg_manager check-update; then
                log_info "$pkg_manager package lists updated successfully"
                return 0
            else
                # check-update returns 100 when updates are available, which is normal
                local exit_code=$?
                if [[ $exit_code -eq 100 ]]; then
                    log_info "$pkg_manager package lists updated successfully (updates available)"
                    return 0
                else
                    log_error "Failed to update $pkg_manager package lists"
                    return 1
                fi
            fi
            ;;
        *)
            log_error "Unsupported distribution: $distro"
            return 1
            ;;
    esac
}

# Upgrade system packages
upgrade_system_packages() {
    local distro=$(detect_distro)
    local upgrade_mode="${1:-interactive}"  # interactive, automatic, security-only
    
    log_info "Upgrading system packages (mode: $upgrade_mode)"
    
    case $distro in
        ubuntu|debian|mint|pop)
            case $upgrade_mode in
                automatic)
                    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
                    ;;
                security-only)
                    sudo apt-get upgrade -y --only-upgrade $(apt list --upgradable 2>/dev/null | grep -i security | awk -F/ '{print $1}')
                    ;;
                *)
                    # Interactive mode - show what will be upgraded
                    local upgradable_count=$(apt list --upgradable 2>/dev/null | grep -v "WARNING" | wc -l)
                    if [[ $upgradable_count -gt 0 ]]; then
                        echo -e "${CYAN}Packages available for upgrade: $upgradable_count${NC}"
                        if prompt_yes_no "Show package list before upgrading?" "n"; then
                            apt list --upgradable 2>/dev/null | grep -v "WARNING"
                        fi
                        
                        if prompt_yes_no "Proceed with package upgrade?" "y"; then
                            sudo apt-get upgrade -y
                        else
                            log_info "Package upgrade skipped by user"
                            return 0
                        fi
                    else
                        log_info "No packages available for upgrade"
                        return 0
                    fi
                    ;;
            esac
            
            if [[ $? -eq 0 ]]; then
                log_info "System packages upgraded successfully"
            else
                log_error "Failed to upgrade system packages"
                return 1
            fi
            ;;
        centos|fedora|rhel|rocky|almalinux)
            local pkg_manager="yum"
            if command -v dnf >/dev/null 2>&1; then
                pkg_manager="dnf"
            fi
            
            case $upgrade_mode in
                automatic)
                    sudo $pkg_manager update -y
                    ;;
                security-only)
                    sudo $pkg_manager update --security -y
                    ;;
                *)
                    if prompt_yes_no "Proceed with package upgrade using $pkg_manager?" "y"; then
                        sudo $pkg_manager update -y
                    else
                        log_info "Package upgrade skipped by user"
                        return 0
                    fi
                    ;;
            esac
            
            if [[ $? -eq 0 ]]; then
                log_info "System packages upgraded successfully"
            else
                log_error "Failed to upgrade system packages"
                return 1
            fi
            ;;
    esac
    
    # Check if reboot is required
    check_reboot_required
    
    return 0
}

# Install essential packages
install_essential_packages() {
    local distro=$(detect_distro)
    local install_dev="${1:-false}"
    
    log_info "Installing essential packages for $distro"
    
    case $distro in
        ubuntu|debian|mint|pop)
            local packages=("${DEBIAN_ESSENTIAL_PACKAGES[@]}")
            if [[ "$install_dev" == "true" ]]; then
                packages+=("${DEBIAN_DEV_PACKAGES[@]}")
                log_info "Including development packages"
            fi
            
            log_info "Installing ${#packages[@]} packages"
            
            # Install packages with error handling
            local failed_packages=()
            for package in "${packages[@]}"; do
                if sudo apt-get install -y "$package"; then
                    log_info "✓ Installed: $package"
                else
                    log_warn "✗ Failed to install: $package"
                    failed_packages+=("$package")
                fi
            done
            
            if [[ ${#failed_packages[@]} -gt 0 ]]; then
                log_warn "Failed to install packages: ${failed_packages[*]}"
                return 1
            fi
            ;;
        centos|fedora|rhel|rocky|almalinux)
            local pkg_manager="yum"
            if command -v dnf >/dev/null 2>&1; then
                pkg_manager="dnf"
            fi
            
            local packages=("${REDHAT_ESSENTIAL_PACKAGES[@]}")
            if [[ "$install_dev" == "true" ]]; then
                packages+=("${REDHAT_DEV_PACKAGES[@]}")
                log_info "Including development packages"
            fi
            
            log_info "Installing ${#packages[@]} packages with $pkg_manager"
            
            # Install EPEL first for additional packages
            sudo $pkg_manager install -y epel-release || log_warn "EPEL repository may not be available"
            
            # Install packages
            local failed_packages=()
            for package in "${packages[@]}"; do
                if sudo $pkg_manager install -y "$package"; then
                    log_info "✓ Installed: $package"
                else
                    log_warn "✗ Failed to install: $package"
                    failed_packages+=("$package")
                fi
            done
            
            if [[ ${#failed_packages[@]} -gt 0 ]]; then
                log_warn "Failed to install packages: ${failed_packages[*]}"
                return 1
            fi
            ;;
    esac
    
    log_info "Essential packages installation completed"
    return 0
}

# Clean up package cache and remove unnecessary packages
cleanup_packages() {
    local distro=$(detect_distro)
    
    log_info "Cleaning up package cache and removing unnecessary packages"
    
    case $distro in
        ubuntu|debian|mint|pop)
            # Remove packages that were automatically installed but no longer needed
            log_info "Removing unused packages"
            sudo apt-get autoremove -y
            
            # Clean package cache
            log_info "Cleaning package cache"
            sudo apt-get autoclean
            sudo apt-get clean
            
            # Fix any broken dependencies
            sudo apt-get -f install -y
            ;;
        centos|fedora|rhel|rocky|almalinux)
            local pkg_manager="yum"
            if command -v dnf >/dev/null 2>&1; then
                pkg_manager="dnf"
            fi
            
            # Remove unused packages
            log_info "Removing unused packages"
            sudo $pkg_manager autoremove -y
            
            # Clean package cache
            log_info "Cleaning package cache"
            sudo $pkg_manager clean all
            ;;
    esac
    
    log_info "Package cleanup completed"
}

# Check if reboot is required
check_reboot_required() {
    local distro=$(detect_distro)
    
    case $distro in
        ubuntu|debian|mint|pop)
            if [[ -f /var/run/reboot-required ]]; then
                local packages=""
                if [[ -f /var/run/reboot-required.pkgs ]]; then
                    packages=" ($(cat /var/run/reboot-required.pkgs | tr '\n' ' '))"
                fi
                set_reboot_needed "Kernel or critical system packages were updated$packages"
                return 0
            fi
            ;;
        centos|fedora|rhel|rocky|almalinux)
            # Check if kernel was updated
            local running_kernel=$(uname -r)
            local installed_kernel=$(rpm -q kernel --last | head -1 | awk '{print $1}' | sed 's/kernel-//')
            
            if [[ "$running_kernel" != "$installed_kernel" ]]; then
                set_reboot_needed "New kernel installed: $installed_kernel (currently running: $running_kernel)"
                return 0
            fi
            ;;
    esac
    
    return 1
}

# Configure automatic updates
configure_automatic_updates() {
    local distro=$(detect_distro)
    local enable_auto="${1:-false}"
    
    if [[ "$enable_auto" != "true" ]]; then
        if ! prompt_yes_no "Configure automatic security updates?" "y"; then
            log_info "Automatic updates configuration skipped"
            return 0
        fi
    fi
    
    log_info "Configuring automatic updates for $distro"
    
    case $distro in
        ubuntu|debian|mint|pop)
            # Install unattended-upgrades
            sudo apt-get install -y unattended-upgrades apt-listchanges
            
            # Configure unattended-upgrades
            cat > /tmp/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Whitelist {
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::DevRelease "auto";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "false";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::SyslogFacility "daemon";
EOF
            
            sudo mv /tmp/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades
            
            # Enable automatic updates
            echo 'APT::Periodic::Update-Package-Lists "1";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades
            echo 'APT::Periodic::Unattended-Upgrade "1";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades
            
            # Enable and start the service
            sudo systemctl enable unattended-upgrades
            sudo systemctl start unattended-upgrades
            
            log_info "Automatic security updates configured"
            ;;
        centos|fedora|rhel|rocky|almalinux)
            # Install and configure dnf-automatic or yum-cron
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y dnf-automatic
                
                # Configure dnf-automatic
                sudo sed -i 's/apply_updates = no/apply_updates = yes/' /etc/dnf/automatic.conf
                sudo sed -i 's/upgrade_type = default/upgrade_type = security/' /etc/dnf/automatic.conf
                
                sudo systemctl enable --now dnf-automatic.timer
                log_info "DNF automatic security updates configured"
            else
                sudo yum install -y yum-cron
                
                # Configure yum-cron
                sudo sed -i 's/apply_updates = no/apply_updates = yes/' /etc/yum/yum-cron.conf
                sudo sed -i 's/update_cmd = default/update_cmd = security/' /etc/yum/yum-cron.conf
                
                sudo systemctl enable --now yum-cron
                log_info "YUM-cron automatic security updates configured"
            fi
            ;;
    esac
}

# =============================================================================
# MAIN UPDATE FUNCTIONS
# =============================================================================

# Complete system update process
full_system_update() {
    local install_dev="${1:-false}"
    local enable_auto_updates="${2:-false}"
    
    log_info "Starting complete system update process"
    
    # Check system requirements
    if ! check_system_requirements; then
        log_error "System requirements check failed"
        return 1
    fi
    
    # Update package lists
    if ! update_package_lists; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Upgrade system packages
    if ! upgrade_system_packages; then
        log_error "Failed to upgrade system packages"
        return 1
    fi
    
    # Install essential packages
    if ! install_essential_packages "$install_dev"; then
        log_warn "Some essential packages failed to install"
    fi
    
    # Configure automatic updates
    configure_automatic_updates "$enable_auto_updates"
    
    # Clean up
    cleanup_packages
    
    log_info "Complete system update process finished"
    
    # Show summary
    echo -e "\n${CYAN}=== Update Summary ===${NC}"
    echo -e "${WHITE}✓ Package lists updated${NC}"
    echo -e "${WHITE}✓ System packages upgraded${NC}"
    echo -e "${WHITE}✓ Essential packages installed${NC}"
    echo -e "${WHITE}✓ Package cache cleaned${NC}"
    
    if [[ $reboot_needed -eq 1 ]]; then
        echo -e "${YELLOW}⚠ System reboot recommended${NC}"
    else
        echo -e "${GREEN}✓ No reboot required${NC}"
    fi
    
    return 0
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

usage() {
    cat << EOF
Usage: $0 [options]

System update and package management module.

Options:
    -h, --help          Display this help message
    -f, --full          Perform complete system update
    -u, --update-only   Update package lists only
    -g, --upgrade-only  Upgrade packages only
    -i, --install       Install essential packages only
    -d, --dev           Include development packages
    -a, --auto          Configure automatic updates
    -c, --cleanup       Clean package cache only
    -s, --security      Security updates only
    --check             Check system requirements only

Examples:
    $0 -f               # Complete system update
    $0 -f -d            # Complete update with dev packages
    $0 -u -g            # Update lists and upgrade packages
    $0 -s               # Security updates only
    $0 --check          # Check requirements only

EOF
    exit 0
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local full_update=false
    local update_only=false
    local upgrade_only=false
    local install_only=false
    local include_dev=false
    local configure_auto=false
    local cleanup_only=false
    local security_only=false
    local check_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -f|--full)
                full_update=true
                shift
                ;;
            -u|--update-only)
                update_only=true
                shift
                ;;
            -g|--upgrade-only)
                upgrade_only=true
                shift
                ;;
            -i|--install)
                install_only=true
                shift
                ;;
            -d|--dev)
                include_dev=true
                shift
                ;;
            -a|--auto)
                configure_auto=true
                shift
                ;;
            -c|--cleanup)
                cleanup_only=true
                shift
                ;;
            -s|--security)
                security_only=true
                shift
                ;;
            --check)
                check_only=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    log_info "Flux system update module started"
    
    # Handle individual operations
    if [[ "$check_only" == true ]]; then
        check_system_requirements
        exit $?
    fi
    
    if [[ "$cleanup_only" == true ]]; then
        cleanup_packages
        exit $?
    fi
    
    if [[ "$update_only" == true ]]; then
        update_package_lists
        exit $?
    fi
    
    if [[ "$upgrade_only" == true ]]; then
        if [[ "$security_only" == true ]]; then
            upgrade_system_packages "security-only"
        else
            upgrade_system_packages "interactive"
        fi
        exit $?
    fi
    
    if [[ "$install_only" == true ]]; then
        install_essential_packages "$include_dev"
        exit $?
    fi
    
    if [[ "$configure_auto" == true ]]; then
        configure_automatic_updates "true"
        exit $?
    fi
    
    if [[ "$full_update" == true ]]; then
        full_system_update "$include_dev" "$configure_auto"
        exit $?
    fi
    
    # If no options specified, show usage
    if [[ $# -eq 0 ]]; then
        usage
    fi
}

# Run main function with all arguments
main "$@"
