#!/bin/bash

# flux-helpers.sh - Reusable helper functions for Flux scripts
# Source this file in other scripts: source ./flux-helpers.sh

# =============================================================================
# GLOBAL VARIABLES & CONFIGURATION
# =============================================================================

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Log levels
readonly LOG_DEBUG=0
readonly LOG_INFO=1
readonly LOG_WARN=2
readonly LOG_ERROR=3

# Default log level (can be overridden)
LOG_LEVEL=${LOG_LEVEL:-$LOG_INFO}

# Default log file
LOGFILE=${LOGFILE:-"/var/log/flux-setup.log"}

# Global reboot tracking
reboot_needed=${reboot_needed:-0}

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

# Initialize logging (create log file, set permissions)
init_logging() {
    local logdir=$(dirname "$LOGFILE")
    if [[ ! -d "$logdir" ]]; then
        sudo mkdir -p "$logdir" 2>/dev/null || {
            echo -e "${YELLOW}Warning: Cannot create log directory $logdir. Using /tmp${NC}" >&2
            LOGFILE="/tmp/flux-setup.log"
        }
    fi
    
    # Create log file if it doesn't exist
    if [[ ! -f "$LOGFILE" ]]; then
        sudo touch "$LOGFILE" 2>/dev/null || touch "$LOGFILE"
        sudo chmod 644 "$LOGFILE" 2>/dev/null || chmod 644 "$LOGFILE"
    fi
}

# Generic logging function
log() {
    local level=$1
    local level_num=$2
    local color=$3
    shift 3
    
    # Check if we should log this level
    if [[ $level_num -lt $LOG_LEVEL ]]; then
        return 0
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="$*"
    local log_entry="[$timestamp] [$level] $message"
    
    # Write to log file
    echo "$log_entry" >> "$LOGFILE" 2>/dev/null || echo "$log_entry" >> /tmp/flux-setup.log
    
    # Output to console with color
    echo -e "${color}[$level]${NC} $message"
}

# Specific log level functions
log_debug() { log "DEBUG" $LOG_DEBUG "$CYAN" "$@"; }
log_info() { log "INFO" $LOG_INFO "$GREEN" "$@"; }
log_warn() { log "WARN" $LOG_WARN "$YELLOW" "$@"; }
log_error() { log "ERROR" $LOG_ERROR "$RED" "$@"; }
log_success() { log "SUCCESS" $LOG_INFO "$GREEN" "✓ $*"; }

# =============================================================================
# INPUT VALIDATION FUNCTIONS
# =============================================================================

# Validate IP address (proper range checking)
validate_ip() {
    local ip=$1
    local IFS='.'
    local -a octets=($ip)
    
    # Check format: exactly 4 octets
    if [[ ${#octets[@]} -ne 4 ]]; then
        return 1
    fi
    
    # Check each octet
    for octet in "${octets[@]}"; do
        # Check if it's a number
        if [[ ! "$octet" =~ ^[0-9]+$ ]]; then
            return 1
        fi
        
        # Check range (0-255)
        if [[ $octet -lt 0 || $octet -gt 255 ]]; then
            return 1
        fi
        
        # Check for leading zeros (except for "0")
        if [[ ${#octet} -gt 1 && ${octet:0:1} == "0" ]]; then
            return 1
        fi
    done
    
    return 0
}

# Validate hostname/FQDN
validate_hostname() {
    local hostname=$1
    
    # Check length (1-253 characters)
    if [[ ${#hostname} -eq 0 || ${#hostname} -gt 253 ]]; then
        return 1
    fi
    
    # Check format: alphanumeric, hyphens, dots
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        return 1
    fi
    
    # Cannot start or end with hyphen or dot
    if [[ "$hostname" =~ ^[-.]|[-.]$ ]]; then
        return 1
    fi
    
    return 0
}

# Validate network interface name
validate_interface() {
    local interface=$1
    
    # Check if interface exists
    if [[ ! -d "/sys/class/net/$interface" ]]; then
        return 1
    fi
    
    return 0
}

# Validate VLAN ID (1-4094)
validate_vlan() {
    local vlan=$1
    
    if [[ ! "$vlan" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    if [[ $vlan -lt 1 || $vlan -gt 4094 ]]; then
        return 1
    fi
    
    return 0
}

# Validate port number (1-65535)
validate_port() {
    local port=$1

    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    if [[ $port -lt 1 || $port -gt 65535 ]]; then
        return 1
    fi

    return 0
}

# Validate email address
validate_email() {
    local email=$1
    local regex='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

    [[ "$email" =~ $regex ]]
}

# Validate URL
validate_url() {
    local url=$1
    local regex='^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/.*)?$'

    [[ "$url" =~ $regex ]]
}

# Validate CIDR notation
validate_cidr() {
    local cidr=$1

    # Split IP and prefix
    if [[ ! "$cidr" =~ ^([0-9.]+)/([0-9]+)$ ]]; then
        return 1
    fi

    local ip="${BASH_REMATCH[1]}"
    local prefix="${BASH_REMATCH[2]}"

    # Validate IP part
    validate_ip "$ip" || return 1

    # Validate prefix (0-32)
    if [[ $prefix -lt 0 || $prefix -gt 32 ]]; then
        return 1
    fi

    return 0
}

# Validate username (POSIX compliant)
validate_username() {
    local username=$1

    # Must start with letter or underscore, 1-32 chars, alphanumeric + underscore/hyphen
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        return 1
    fi

    return 0
}

# =============================================================================
# USER INPUT FUNCTIONS
# =============================================================================

# Generic yes/no prompt with default
prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    
    # Format the prompt based on default
    if [[ "$default" == "y" || "$default" == "Y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    while true; do
        read -p "$prompt" response
        
        # Use default if empty response
        if [[ -z "$response" ]]; then
            response="$default"
        fi
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

# Prompt for input with validation
prompt_with_validation() {
    local prompt="$1"
    local validation_func="$2"
    local default="$3"
    local error_msg="${4:-Invalid input. Please try again.}"
    local input
    
    while true; do
        if [[ -n "$default" ]]; then
            read -p "$prompt [default: $default]: " input
            if [[ -z "$input" ]]; then
                input="$default"
            fi
        else
            read -p "$prompt: " input
        fi
        
        # If no validation function, just return the input
        if [[ -z "$validation_func" ]]; then
            echo "$input"
            return 0
        fi
        
        # Run validation
        if $validation_func "$input"; then
            echo "$input"
            return 0
        else
            echo -e "${RED}$error_msg${NC}" >&2
        fi
    done
}

# Prompt for IP address
prompt_ip() {
    local prompt="$1"
    local default="$2"
    prompt_with_validation "$prompt" "validate_ip" "$default" "Invalid IP address format (e.g., 192.168.1.100)"
}

# Prompt for hostname
prompt_hostname() {
    local prompt="$1"
    local default="$2"
    prompt_with_validation "$prompt" "validate_hostname" "$default" "Invalid hostname format"
}

# Prompt for network interface with list
prompt_interface() {
    local prompt="$1"
    local show_list="${2:-true}"
    
    if [[ "$show_list" == "true" ]]; then
        echo -e "${CYAN}Available network interfaces:${NC}"
        ip link show | grep -E '^[0-9]+:' | awk -F': ' '{print "  " $2}' | grep -v lo
        echo
    fi
    
    prompt_with_validation "$prompt" "validate_interface" "" "Interface does not exist"
}

# =============================================================================
# FILE OPERATIONS & BACKUP FUNCTIONS
# =============================================================================

# Create backup of a file with timestamp
backup_file() {
    local file="$1"
    local backup_dir="${2:-$(dirname "$file")}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="$(basename "$file").backup_$timestamp"
    local backup_path="$backup_dir/$backup_name"
    
    if [[ ! -f "$file" ]]; then
        log_warn "File $file does not exist, skipping backup"
        return 1
    fi
    
    # Create backup directory if it doesn't exist
    if [[ ! -d "$backup_dir" ]]; then
        sudo mkdir -p "$backup_dir" || {
            log_error "Failed to create backup directory: $backup_dir"
            return 1
        }
    fi
    
    # Create backup
    if sudo cp "$file" "$backup_path"; then
        log_info "Backed up $file to $backup_path"
        echo "$backup_path"
        return 0
    else
        log_error "Failed to backup $file"
        return 1
    fi
}

# Safe file write with backup
safe_write_file() {
    local file="$1"
    local content="$2"
    local backup_existing="${3:-true}"
    local temp_file="/tmp/$(basename "$file").tmp.$$"
    
    # Backup existing file if requested
    if [[ "$backup_existing" == "true" && -f "$file" ]]; then
        backup_file "$file" || {
            log_error "Failed to backup $file before writing"
            return 1
        }
    fi
    
    # Write to temp file first
    if echo "$content" > "$temp_file"; then
        # Move temp file to final location
        if sudo mv "$temp_file" "$file"; then
            log_info "Successfully wrote to $file"
            return 0
        else
            log_error "Failed to move temp file to $file"
            rm -f "$temp_file"
            return 1
        fi
    else
        log_error "Failed to write to temp file $temp_file"
        return 1
    fi
}

# Safe append to file with backup
safe_append_file() {
    local file="$1"
    local content="$2"
    local backup_existing="${3:-true}"
    
    # Backup existing file if requested
    if [[ "$backup_existing" == "true" && -f "$file" ]]; then
        backup_file "$file" || {
            log_error "Failed to backup $file before appending"
            return 1
        }
    fi
    
    # Append content
    if echo "$content" | sudo tee -a "$file" > /dev/null; then
        log_info "Successfully appended to $file"
        return 0
    else
        log_error "Failed to append to $file"
        return 1
    fi
}

# =============================================================================
# NETWORK HELPER FUNCTIONS
# =============================================================================

# Get default gateway
get_default_gateway() {
    ip route show default | awk '/default/ { print $3 }' | head -1
}

# Get primary DNS server from resolv.conf
get_primary_dns() {
    grep -E '^nameserver' /etc/resolv.conf | head -1 | awk '{print $2}'
}

# Check if interface supports VLANs
interface_supports_vlan() {
    local interface="$1"
    
    # Check if 8021q module is loaded
    if ! lsmod | grep -q 8021q; then
        log_warn "802.1Q VLAN module not loaded. Loading now..."
        sudo modprobe 8021q || {
            log_error "Failed to load 8021Q module"
            return 1
        }
    fi
    
    return 0
}

# =============================================================================
# SYSTEM DETECTION FUNCTIONS
# =============================================================================

# Detect Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Check if systemd is available
has_systemd() {
    command -v systemctl >/dev/null 2>&1
}

# Check if a command exists
check_command() {
    local cmd="$1"
    local package="${2:-$cmd}"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "Required command not found: $cmd"
        log_info "Install it with your package manager (e.g., apt install $package)"
        return 1
    fi
    return 0
}

# Require root privileges
require_root() {
    if ! is_root; then
        log_error "This operation requires root privileges"
        log_info "Please run with sudo or as root user"
        exit 1
    fi
}

# Detect package manager
detect_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    else
        echo "unknown"
        return 1
    fi
}

# Check internet connectivity
check_internet() {
    local test_hosts=("8.8.8.8" "1.1.1.1" "208.67.222.222")

    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
            return 0
        fi
    done

    log_warn "No internet connectivity detected"
    return 1
}

# =============================================================================
# PACKAGE MANAGEMENT HELPERS
# =============================================================================

# Install package using detected package manager
install_package() {
    local package="$1"
    local pkg_manager=$(detect_package_manager)

    log_info "Installing package: $package"

    case "$pkg_manager" in
        apt)
            sudo apt-get update -qq && sudo apt-get install -y "$package"
            ;;
        dnf)
            sudo dnf install -y "$package"
            ;;
        yum)
            sudo yum install -y "$package"
            ;;
        zypper)
            sudo zypper install -y "$package"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$package"
            ;;
        *)
            log_error "Unsupported package manager"
            return 1
            ;;
    esac
}

# Check if package is installed
is_package_installed() {
    local package="$1"
    local pkg_manager=$(detect_package_manager)

    case "$pkg_manager" in
        apt)
            dpkg -l "$package" 2>/dev/null | grep -q ^ii
            ;;
        dnf|yum)
            rpm -q "$package" >/dev/null 2>&1
            ;;
        zypper)
            rpm -q "$package" >/dev/null 2>&1
            ;;
        pacman)
            pacman -Q "$package" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

# =============================================================================
# UI HELPER FUNCTIONS
# =============================================================================

# Show a spinner while running a command
show_spinner() {
    local pid=$1
    local message="${2:-Processing}"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    echo -n "$message "
    while kill -0 $pid 2>/dev/null; do
        i=$(((i + 1) % 10))
        printf "\r%s %s" "$message" "${spin:$i:1}"
        sleep 0.1
    done
    printf "\r%s ✓\n" "$message"
}

# Print a separator line
print_separator() {
    local char="${1:--}"
    local width="${2:-80}"
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

# Print a header
print_header() {
    local text="$1"
    local color="${2:-$CYAN}"

    echo
    print_separator "="
    echo -e "${color}${text}${NC}"
    print_separator "="
    echo
}

# =============================================================================
# DOWNLOAD & VERIFICATION FUNCTIONS
# =============================================================================

# Safe download with verification
safe_download() {
    local url="$1"
    local destination="$2"
    local verify_ssl="${3:-true}"
    local max_retries="${4:-3}"
    local retry_count=0
    
    # Create destination directory if needed
    local dest_dir=$(dirname "$destination")
    if [[ ! -d "$dest_dir" ]]; then
        sudo mkdir -p "$dest_dir" || {
            log_error "Failed to create directory: $dest_dir"
            return 1
        }
    fi
    
    while [[ $retry_count -lt $max_retries ]]; do
        log_info "Downloading $url (attempt $((retry_count + 1))/$max_retries)"
        
        local wget_opts="-q -O"
        if [[ "$verify_ssl" == "false" ]]; then
            wget_opts="$wget_opts --no-check-certificate"
        fi
        
        if wget $wget_opts "$destination" "$url"; then
            log_info "Successfully downloaded to $destination"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [[ $retry_count -lt $max_retries ]]; then
                log_warn "Download failed, retrying in 2 seconds..."
                sleep 2
            fi
        fi
    done
    
    log_error "Failed to download $url after $max_retries attempts"
    return 1
}

# Verify file checksum
verify_checksum() {
    local file="$1"
    local expected_checksum="$2"
    local algorithm="${3:-sha256}"
    
    if [[ ! -f "$file" ]]; then
        log_error "File $file does not exist"
        return 1
    fi
    
    local actual_checksum
    case "$algorithm" in
        md5)
            actual_checksum=$(md5sum "$file" | awk '{print $1}')
            ;;
        sha1)
            actual_checksum=$(sha1sum "$file" | awk '{print $1}')
            ;;
        sha256)
            actual_checksum=$(sha256sum "$file" | awk '{print $1}')
            ;;
        *)
            log_error "Unsupported checksum algorithm: $algorithm"
            return 1
            ;;
    esac
    
    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
        log_info "Checksum verification passed for $file"
        return 0
    else
        log_error "Checksum verification failed for $file"
        log_error "Expected: $expected_checksum"
        log_error "Actual: $actual_checksum"
        return 1
    fi
}

# =============================================================================
# ERROR HANDLING & CLEANUP
# =============================================================================

# Generic error handler
handle_error() {
    local exit_code=$?
    local line_number=${BASH_LINENO[0]}
    local command="${BASH_COMMAND}"
    local script_name="${BASH_SOURCE[1]}"
    
    log_error "Error occurred in $script_name:$line_number"
    log_error "Failed command: $command"
    log_error "Exit code: $exit_code"
    
    # Call cleanup if function exists
    if declare -f cleanup >/dev/null; then
        log_info "Running cleanup..."
        cleanup
    fi
    
    exit $exit_code
}

# Set up error handling (call this in your main scripts)
setup_error_handling() {
    set -euo pipefail
    trap handle_error ERR
    trap 'log_info "Script interrupted by user"; exit 130' INT TERM
}

# =============================================================================
# REBOOT MANAGEMENT
# =============================================================================

# Set reboot needed flag
set_reboot_needed() {
    local reason="${1:-System configuration changed}"
    reboot_needed=1
    log_warn "Reboot will be needed: $reason"
}

# Check if reboot is needed and prompt user
check_reboot_needed() {
    if [[ $reboot_needed -eq 1 ]]; then
        echo -e "${YELLOW}A system reboot is recommended to apply all changes.${NC}"
        if prompt_yes_no "Reboot now?" "n"; then
            log_info "Rebooting system as requested by user"
            sudo reboot
        else
            log_info "Reboot deferred by user. Please reboot manually when convenient."
        fi
    fi
}

# =============================================================================
# INITIALIZATION
# =============================================================================

# Initialize the helper library
init_flux_helpers() {
    init_logging
    log_info "Flux helpers library initialized"
}

# Auto-initialize when sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_flux_helpers
fi
