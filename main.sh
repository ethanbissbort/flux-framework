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
readonly MODULE_PREFIX="flux-"
readonly MODULE_SUFFIX="-module.sh"

# Core components
readonly HELPER_LIBRARY="flux-helpers.sh"
readonly CONFIG_FILE="$FLUX_CONFIG_DIR/flux.conf" # TODO: Implement config management for installs of framework. Not applicable to portable utilization.

# Create default configuration
init_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        mkdir -p "$(dirname "$CONFIG_FILE")"
        local config_date=$(date '+%Y-%m-%d %H:%M:%S')
        cat > "$CONFIG_FILE" << EOCONF
# Flux Framework Configuration
# Generated: ${config_date}

# Logging Configuration
LOG_LEVEL=1  # 0=debug, 1=info, 2=warn, 3=error
LOGFILE="/var/log/flux-setup.log"

# Color Output
USE_COLORS=true

# Module Settings
AUTO_UPDATE_MODULES=false
MODULE_TIMEOUT=300

# Network Defaults
DEFAULT_DNS_PRIMARY="1.1.1.1"
DEFAULT_DNS_SECONDARY="8.8.8.8"

# SSH Defaults
DEFAULT_SSH_PORT="22"

# Update Settings
AUTO_SECURITY_UPDATES=true
EOCONF
        log_info "Created default configuration: $CONFIG_FILE"
    fi
}
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
        log_info "Searched locations:"
        for path in "${search_paths[@]}"; do
            log_debug "  - $path"
        done
        log_info "Run '$(basename "$0") list' to see available modules"
        return 1
    fi

    # Make executable if needed
    if [[ ! -x "$module_file" ]]; then
        log_debug "Making module executable: $module_file"
        chmod +x "$module_file" 2>/dev/null || {
            log_error "Failed to make module executable (permission denied)"
            return 1
        }
    fi

    # Verify module can be sourced (syntax check)
    if ! bash -n "$module_file" 2>/dev/null; then
        log_error "Module has syntax errors: $module_name"
        return 1
    fi

    log_info "Loading module: $module_name"
    log_debug "Module path: $module_file"
    log_debug "Module args: ${module_args[*]:-none}"

    # Execute module with timeout if configured
    local exit_code=0
    if [[ -n "${MODULE_TIMEOUT:-}" && "${MODULE_TIMEOUT}" -gt 0 ]]; then
        timeout "${MODULE_TIMEOUT}" "$module_file" "${module_args[@]}"
        exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "Module $module_name timed out after ${MODULE_TIMEOUT}s"
            return 1
        fi
    else
        "$module_file" "${module_args[@]}"
        exit_code=$?
    fi

    if [[ $exit_code -eq 0 ]]; then
        log_success "Module $module_name completed successfully"
        return 0
    else
        log_error "Module $module_name failed with exit code: $exit_code"
        return 1
    fi
}

# =============================================================================
# WORKFLOW MANAGEMENT
# =============================================================================

# Define workflow configurations
declare -A WORKFLOWS=(
    ["essential"]="update,certs,sysctl,ssh"
    ["complete"]="update,locale,hostname,user,certs,sysctl,ssh,zsh,motd,netdata"
    ["security"]="update,certs,sysctl,ssh,firewall"
    ["development"]="update,zsh"
    ["monitoring"]="update,netdata"
)

# Workflow descriptions
declare -A WORKFLOW_DESCRIPTIONS=(
    ["essential"]="Basic system setup (updates, certs, kernel hardening, SSH)"
    ["complete"]="Full system configuration with all modules"
    ["security"]="Security-focused hardening workflow"
    ["development"]="Development environment setup"
    ["monitoring"]="Monitoring tools installation"
)

# List available workflows
list_workflows() {
    print_header "Available Workflows"

    for workflow in "${!WORKFLOWS[@]}"; do
        local desc="${WORKFLOW_DESCRIPTIONS[$workflow]:-No description}"
        local modules="${WORKFLOWS[$workflow]}"
        local module_count=$(echo "$modules" | tr ',' '\n' | wc -l)

        echo -e "${WHITE}${workflow}${NC}"
        echo "  Description: $desc"
        echo "  Modules ($module_count): ${CYAN}${modules}${NC}"
        echo
    done
}

# Execute workflow
execute_workflow() {
    local workflow_name="$1"
    local non_interactive="${2:-false}"
    local workflow_modules="${WORKFLOWS[$workflow_name]:-}"

    if [[ -z "$workflow_modules" ]]; then
        log_error "Unknown workflow: $workflow_name"
        echo
        list_workflows
        return 1
    fi

    log_info "Executing workflow: $workflow_name"
    print_header "Workflow: $workflow_name"

    local desc="${WORKFLOW_DESCRIPTIONS[$workflow_name]:-}"
    [[ -n "$desc" ]] && echo -e "${CYAN}$desc${NC}\n"

    # Parse modules from workflow
    IFS=',' read -ra modules <<< "$workflow_modules"

    echo "This workflow will execute ${#modules[@]} modules:"
    for module in "${modules[@]}"; do
        echo "  - $module"
    done
    echo

    if [[ "$non_interactive" != "true" ]]; then
        if ! prompt_yes_no "Proceed with workflow?" "y"; then
            log_info "Workflow cancelled by user"
            return 0
        fi
        echo
    fi

    local completed=0
    local failed=0
    local skipped=0
    local start_time=$(date +%s)

    for module in "${modules[@]}"; do
        print_separator "-"
        echo -e "${WHITE}[Step $((completed + failed + skipped + 1))/${#modules[@]}] Module: $module${NC}"
        print_separator "-"

        if [[ "$non_interactive" == "true" ]] || prompt_yes_no "Execute $module module?" "y"; then
            if load_module "$module"; then
                ((completed++))
            else
                ((failed++))
                log_error "Module $module failed"
                if [[ "$non_interactive" != "true" ]]; then
                    if ! prompt_yes_no "Continue with remaining modules?" "y"; then
                        log_warn "Workflow aborted by user"
                        break
                    fi
                fi
            fi
        else
            ((skipped++))
            log_info "Skipped module: $module"
        fi
        echo
    done

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Summary
    print_header "Workflow Summary"
    echo "Workflow: $workflow_name"
    echo "Duration: ${duration}s"
    echo
    echo -e "${GREEN}✓ Completed: $completed${NC}"
    [[ $failed -gt 0 ]] && echo -e "${RED}✗ Failed: $failed${NC}"
    [[ $skipped -gt 0 ]] && echo -e "${YELLOW}○ Skipped: $skipped${NC}"
    echo

    check_reboot_needed

    # Return non-zero if any module failed
    [[ $failed -eq 0 ]]
}

# =============================================================================
# SYSTEM MANAGEMENT
# =============================================================================

# Check system status
check_system_status() {
    print_header "System Status Check"

    # Basic system info
    echo -e "${WHITE}System Information:${NC}"
    if command -v lsb_release >/dev/null 2>&1; then
        echo "  OS: $(lsb_release -ds 2>/dev/null)"
    elif [[ -f /etc/os-release ]]; then
        echo "  OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    else
        echo "  OS: Unknown"
    fi
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  Hostname: $(hostname -f 2>/dev/null || hostname)"
    echo "  Uptime: $(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"

    # Resource usage
    echo -e "\n${WHITE}Resource Usage:${NC}"
    echo "  CPU Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
    echo "  Memory: $(free -h | awk 'NR==2{printf "%s/%s (%.0f%%)", $3, $2, $3*100/$2}')"
    echo "  Disk (/): $(df -h / | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}')"

    # Network
    echo -e "\n${WHITE}Network:${NC}"
    local primary_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    local gateway=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -1)
    echo "  Primary IP: ${primary_ip:-Not configured}"
    echo "  Gateway: ${gateway:-Not configured}"

    # Check internet
    if check_internet >/dev/null 2>&1; then
        echo -e "  Internet: ${GREEN}Connected${NC}"
    else
        echo -e "  Internet: ${RED}Disconnected${NC}"
    fi

    # Services (only if systemd is available)
    if has_systemd; then
        echo -e "\n${WHITE}Key Services:${NC}"
        local services=("ssh" "sshd" "ufw" "firewalld" "fail2ban" "docker" "netdata")
        for service in "${services[@]}"; do
            if systemctl list-unit-files 2>/dev/null | grep -q "^${service}.service"; then
                if systemctl is-active "$service" &>/dev/null; then
                    echo -e "  ${service}: ${GREEN}active${NC}"
                else
                    echo -e "  ${service}: ${YELLOW}inactive${NC}"
                fi
            fi
        done
    fi

    # Updates (distribution-specific)
    echo -e "\n${WHITE}System Updates:${NC}"

    # Check reboot required (Debian/Ubuntu)
    if [[ -f /var/run/reboot-required ]]; then
        echo -e "  ${YELLOW}⚠ Reboot required${NC}"
    fi

    # Check for available updates
    local pkg_manager=$(detect_package_manager)
    case "$pkg_manager" in
        apt)
            local updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo "0")
            if [[ $updates -gt 0 ]]; then
                echo -e "  ${YELLOW}$updates updates available${NC}"
            else
                echo -e "  ${GREEN}✓ System up to date${NC}"
            fi
            ;;
        dnf|yum)
            local updates=$(dnf check-update -q 2>/dev/null | grep -v "^$" | wc -l || echo "0")
            if [[ $updates -gt 0 ]]; then
                echo -e "  ${YELLOW}$updates updates available${NC}"
            else
                echo -e "  ${GREEN}✓ System up to date${NC}"
            fi
            ;;
        *)
            echo "  Check manually (unsupported package manager)"
            ;;
    esac

    echo
}

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

# Load configuration
load_config() {
    init_config
    if [[ -f "$CONFIG_FILE" ]]; then
        if bash -n "$CONFIG_FILE" 2>/dev/null; then
            source "$CONFIG_FILE"
            log_debug "Loaded configuration from $CONFIG_FILE"
        else
            log_warn "Configuration file has syntax errors, using defaults"
        fi
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
${CYAN}Flux System Administration Framework${NC} v$FLUX_VERSION

${WHITE}Usage:${NC} $(basename "$0") [command] [options]

${WHITE}Commands:${NC}
    help                    Show this help message
    version                 Show version information
    list                    List available modules
    workflows               List available workflows
    load MODULE [ARGS]      Load and execute a specific module
    workflow NAME [-y]      Execute a predefined workflow
    status                  Show system status
    config KEY VALUE        Set configuration value

${WHITE}Common Workflows:${NC}
    essential              Basic system setup (update, certs, sysctl, ssh)
    complete               Full system configuration
    security               Security hardening workflow
    development            Development environment setup
    monitoring             Monitoring tools installation

    Run '$(basename "$0") workflows' for detailed workflow information

${WHITE}Example Module Commands:${NC}
    load update            System update and package management
    load network           Network configuration
    load hostname          Hostname configuration
    load user              User management
    load ssh               SSH hardening
    load certs             Certificate installation
    load sysctl            Kernel parameter tuning
    load zsh               ZSH shell installation
    load motd              Custom MOTD setup
    load netdata           NetData monitoring

${WHITE}Examples:${NC}
    $(basename "$0") workflow essential          # Run essential setup (interactive)
    $(basename "$0") workflow security -y        # Run security workflow (non-interactive)
    $(basename "$0") load ssh --help             # Get SSH module help
    $(basename "$0") status                      # Check system status
    $(basename "$0") list                        # List all available modules

${WHITE}Configuration:${NC}
    Config file: $CONFIG_FILE
    Modules dir: $FLUX_MODULES_DIR
    Log file:    \${LOGFILE:-/var/log/flux-setup.log}

For more information, see the documentation in the docs/ directory.

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
        workflows)
            list_workflows
            ;;
        load)
            if [[ $# -eq 0 ]]; then
                log_error "Module name required"
                echo "Usage: $(basename "$0") load MODULE [ARGS]"
                echo "Run '$(basename "$0") list' to see available modules"
                exit 1
            fi
            load_module "$@"
            ;;
        workflow)
            if [[ $# -eq 0 ]]; then
                log_error "Workflow name required"
                echo
                list_workflows
                exit 1
            fi

            local workflow_name="$1"
            local non_interactive="false"
            shift || true

            # Check for -y flag (non-interactive mode)
            if [[ "${1:-}" == "-y" || "${1:-}" == "--yes" ]]; then
                non_interactive="true"
                shift || true
            fi

            execute_workflow "$workflow_name" "$non_interactive"
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
            echo
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
