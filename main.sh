#!/bin/bash

# main.sh - Flux System Administration Framework
# Core orchestrator for modular system configuration

# Strict mode
set -euo pipefail

# Script directory detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# CORE CONFIGURATION
# =============================================================================

# Framework metadata
readonly FLUX_VERSION="3.0.0"
readonly FLUX_RELEASE="2025.05"
readonly FLUX_CONFIG_DIR="${FLUX_CONFIG_DIR:-$HOME/.config/flux}"
readonly FLUX_CONFIG_TEMPLATE_DIR="${FLUX_CONFIG_TEMPLATE_DIR:-$SCRIPT_DIR/config}"
readonly FLUX_MODULES_DIR="${FLUX_MODULES_DIR:-$SCRIPT_DIR/modules}"
readonly FLUX_LEGACY_DIR="${FLUX_LEGACY_DIR:-$SCRIPT_DIR/legacy}"

# Module naming convention
readonly MODULE_PREFIX="flux_"
readonly MODULE_SUFFIX="_module.sh"

# Core components
readonly HELPER_LIBRARY="flux-helpers.sh"
readonly CONFIG_FILE="$FLUX_CONFIG_DIR/flux.conf" # TODO: Implement config management for installs of framework. Not applicable to portable utilization.
#    Items like: Default colors for output, logging levels, etc.

# =============================================================================
# INITIALIZATION
# =============================================================================

# Load helper functions
load_helpers() {
    local helpers_path="$SCRIPT_DIR/$HELPER_LIBRARY"
    
    if [[ ! -f "$helpers_path" ]]; then
        echo "Error: Helper library not found: $helpers_path" >&2
        echo "Flux framework requires $HELPER_LIBRARY to function properly." >&2
        exit 1
    fi
    
    source "$helpers_path"
}

# Initialize framework
init_framework() {
    # Load helpers first
    load_helpers
    
    # Set up error handling from helpers
    setup_error_handling
    
    # Initialize logging
    init_logging
    
    # Create config directory
    mkdir -p "$FLUX_CONFIG_DIR"
    
    # Create modules directory if it doesn't exist
    mkdir -p "$FLUX_MODULES_DIR"
    
    log_info "Flux Framework v$FLUX_VERSION initialized"
}

# =============================================================================
# MODULE MANAGEMENT
# =============================================================================

# Discover available modules
discover_modules() {
    local search_dirs=("$FLUX_MODULES_DIR" "$SCRIPT_DIR")
    local modules=()
    
    for dir in "${search_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            while IFS= read -r module_file; do
                modules+=("$module_file")
            done < <(find "$dir" -maxdepth 1 -name "${MODULE_PREFIX}*${MODULE_SUFFIX}" -type f 2>/dev/null)
        fi
    done
    
    # Remove duplicates and sort
    printf '%s\n' "${modules[@]}" | sort -u
}

# Get module info
get_module_info() {
    local module_path="$1"
    local module_name=$(basename "$module_path" "$MODULE_SUFFIX" | sed "s/^${MODULE_PREFIX}//")
    local module_desc="No description available"
    local module_version="Unknown"
    
    # Try to extract description from module header
    if [[ -f "$module_path" ]]; then
        module_desc=$(grep -m1 "^# .* - " "$module_path" 2>/dev/null | sed 's/^# .* - //' || echo "$module_desc")
        module_version=$(grep -m1 "^# Version: " "$module_path" 2>/dev/null | sed 's/^# Version: //' || echo "$module_version")
    fi
    
    echo "$module_name|$module_desc|$module_version|$module_path"
}

# List available modules
list_modules() {
    log_info "Discovering available modules"
    
    echo -e "${CYAN}=== Available Flux Modules ===${NC}"
    echo
    
    local modules_found=0
    
    while IFS= read -r module_path; do
        if [[ -n "$module_path" ]]; then
            IFS='|' read -r name desc version path <<< "$(get_module_info "$module_path")"
            
            printf "${WHITE}%-20s${NC} " "$name"
            
            if [[ -x "$path" ]]; then
                echo -e "${GREEN}✓${NC} $desc"
            else
                echo -e "${YELLOW}○${NC} $desc (not executable)"
                chmod +x "$path" 2>/dev/null || true
            fi
            
            ((modules_found++))
        fi
    done < <(discover_modules)
    
    if [[ $modules_found -eq 0 ]]; then
        echo -e "${RED}No modules found${NC}"
    else
        echo
        echo -e "${WHITE}Total modules: $modules_found${NC}"
    fi
}

# Load a module
load_module() {
    local module_name="$1"
    shift
    local module_args=("$@")
    
    # Find module file
    local module_file=""
    local search_paths=(
        "$FLUX_MODULES_DIR/${MODULE_PREFIX}${module_name}${MODULE_SUFFIX}"
        "$SCRIPT_DIR/${MODULE_PREFIX}${module_name}${MODULE_SUFFIX}"
        "$FLUX_LEGACY_DIR/${module_name}.sh"
        "$SCRIPT_DIR/${module_name}.sh"
    )
    
    for path in "${search_paths[@]}"; do
        if [[ -f "$path" ]]; then
            module_file="$path"
            break
        fi
    done
    
    if [[ -z "$module_file" ]]; then
        log_error "Module not found: $module_name"
        return 1
    fi
    
    # Make executable if needed
    if [[ ! -x "$module_file" ]]; then
        chmod +x "$module_file"
    fi
    
    log_info "Loading module: $module_name"
    log_debug "Module path: $module_file"
    log_debug "Module args: ${module_args[*]:-none}"
    
    # Execute module
    if "$module_file" "${module_args[@]}"; then
        log_info "Module $module_name completed successfully"
        return 0
    else
        log_error "Module $module_name failed with exit code: $?"
        return 1
    fi
}

# =============================================================================
# WORKFLOW MANAGEMENT
# =============================================================================

# Define workflow configurations
declare -A WORKFLOWS=(
    ["essential"]="update,certs,sysctl,ssh"
    ["complete"]="update,locale,hostname,user,certs,sysctl,ssh,zsh,motd,monitoring"
    ["security"]="update,certs,sysctl,ssh,firewall"
    ["development"]="update,zsh,docker,git"
    ["monitoring"]="update,netdata,prometheus"
)

# Execute workflow
execute_workflow() {
    local workflow_name="$1"
    local workflow_modules="${WORKFLOWS[$workflow_name]:-}"
    
    if [[ -z "$workflow_modules" ]]; then
        log_error "Unknown workflow: $workflow_name"
        echo "Available workflows: ${!WORKFLOWS[*]}"
        return 1
    fi
    
    log_info "Executing workflow: $workflow_name"
    echo -e "${CYAN}=== Workflow: $workflow_name ===${NC}"
    
    # Parse modules from workflow
    IFS=',' read -ra modules <<< "$workflow_modules"
    
    local completed=0
    local failed=0
    local skipped=0
    
    for module in "${modules[@]}"; do
        echo -e "\n${WHITE}[$((completed + failed + skipped + 1))/${#modules[@]}] Module: $module${NC}"
        
        if prompt_yes_no "Execute $module module?" "y"; then
            if load_module "$module"; then
                ((completed++))
            else
                ((failed++))
                if ! prompt_yes_no "Continue with remaining modules?" "y"; then
                    break
                fi
            fi
        else
            ((skipped++))
            log_info "Skipped module: $module"
        fi
    done
    
    # Summary
    echo -e "\n${CYAN}=== Workflow Summary ===${NC}"
    echo -e "${GREEN}✓ Completed: $completed${NC}"
    [[ $failed -gt 0 ]] && echo -e "${RED}✗ Failed: $failed${NC}"
    [[ $skipped -gt 0 ]] && echo -e "${YELLOW}○ Skipped: $skipped${NC}"
    
    check_reboot_needed
    
    return 0
}

# =============================================================================
# SYSTEM MANAGEMENT
# =============================================================================

# Check system status
check_system_status() {
    echo -e "${CYAN}=== System Status Check ===${NC}"
    
    # Basic system info
    echo -e "\n${WHITE}System Information:${NC}"
    echo "  OS: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  Hostname: $(hostname -f 2>/dev/null || hostname)"
    
    # Resource usage
    echo -e "\n${WHITE}Resource Usage:${NC}"
    echo "  CPU Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
    echo "  Memory: $(free -h | awk 'NR==2{printf "%s/%s (%.0f%%)", $3, $2, $3*100/$2}')"
    echo "  Disk (/): $(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')"
    
    # Network
    echo -e "\n${WHITE}Network:${NC}"
    echo "  Primary IP: $(hostname -I | awk '{print $1}')"
    echo "  Gateway: $(ip route | grep default | awk '{print $3}')"
    
    # Services
    echo -e "\n${WHITE}Key Services:${NC}"
    local services=("ssh" "ufw" "fail2ban" "docker" "netdata")
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            if systemctl is-active "$service" &>/dev/null; then
                echo -e "  $service: ${GREEN}active${NC}"
            else
                echo -e "  $service: ${RED}inactive${NC}"
            fi
        fi
    done
    
    # Updates
    echo -e "\n${WHITE}System Updates:${NC}"
    if [[ -f /var/run/reboot-required ]]; then
        echo -e "  ${YELLOW}Reboot required${NC}"
    fi
    
    local updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo "0")
    if [[ $updates -gt 0 ]]; then
        echo "  $updates updates available"
    else
        echo -e "  ${GREEN}System up to date${NC}"
    fi
}

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_debug "Loading configuration from: $CONFIG_FILE"
        source "$CONFIG_FILE"
    fi
}

# Save configuration
save_config() {
    local key="$1"
    local value="$2"
    
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    if grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$CONFIG_FILE"
    else
        echo "${key}=\"${value}\"" >> "$CONFIG_FILE"
    fi
    
    log_debug "Saved config: $key=$value"
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

show_usage() {
    cat << EOF
Flux System Administration Framework v$FLUX_VERSION

Usage: $(basename "$0") [command] [options]

Commands:
    help                Show this help message
    version             Show version information
    list                List available modules
    load MODULE [ARGS]  Load and execute a specific module
    workflow NAME       Execute a predefined workflow
    status              Show system status
    config KEY VALUE    Set configuration value

Workflows:
    essential    - Basic system setup (update, certs, sysctl, ssh)
    complete     - Full system configuration
    security     - Security hardening workflow
    development  - Development environment setup
    monitoring   - Monitoring tools installation

Module Commands:
    load update         System update and package management
    load network        Network configuration
    load hostname       Hostname configuration
    load user           User management
    load ssh            SSH hardening
    load certs          Certificate installation
    load sysctl         Kernel parameter tuning
    load zsh            ZSH shell installation
    load motd           Custom MOTD setup
    load netdata        NetData monitoring

Examples:
    $(basename "$0") workflow essential      # Run essential setup
    $(basename "$0") load ssh --help         # Get SSH module help
    $(basename "$0") status                  # Check system status

EOF
}

show_version() {
    cat << EOF
Flux System Administration Framework
Version: $FLUX_VERSION
Release: $FLUX_RELEASE
Home: $SCRIPT_DIR

Modules Directory: $FLUX_MODULES_DIR
Configuration: $FLUX_CONFIG_DIR

EOF
    list_modules
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Initialize framework
    init_framework
    
    # Load configuration
    load_config
    
    # Parse command
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        help|-h|--help)
            show_usage
            ;;
        version|-v|--version)
            show_version
            ;;
        list)
            list_modules
            ;;
        load)
            if [[ $# -eq 0 ]]; then
                log_error "Module name required"
                echo "Usage: $(basename "$0") load MODULE [ARGS]"
                exit 1
            fi
            load_module "$@"
            ;;
        workflow)
            if [[ $# -eq 0 ]]; then
                log_error "Workflow name required"
                echo "Available workflows: ${!WORKFLOWS[*]}"
                exit 1
            fi
            execute_workflow "$1"
            ;;
        status)
            check_system_status
            ;;
        config)
            if [[ $# -lt 2 ]]; then
                log_error "Configuration requires KEY and VALUE"
                echo "Usage: $(basename "$0") config KEY VALUE"
                exit 1
            fi
            save_config "$1" "$2"
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
