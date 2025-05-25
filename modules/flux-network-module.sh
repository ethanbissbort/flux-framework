#!/bin/bash

# flux_network_module.sh - Network configuration module
# Version: 1.0.0
# Manages network interfaces, VLANs, and network settings

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

# Network defaults
readonly DEFAULT_NETMASK="255.255.255.0"
readonly DEFAULT_GATEWAY=""  # Will be detected if not provided
readonly DEFAULT_DNS_PRIMARY="1.1.1.1"
readonly DEFAULT_DNS_SECONDARY="8.8.8.8"
readonly DEFAULT_DNS_DOMAIN=""
readonly DEFAULT_MTU="1500"

# Network configuration files
readonly INTERFACES_FILE="/etc/network/interfaces"
readonly NETPLAN_DIR="/etc/netplan"
readonly NETWORKMANAGER_DIR="/etc/NetworkManager"

# =============================================================================
# NETWORK DETECTION FUNCTIONS
# =============================================================================

# Detect network management system
detect_network_manager() {
    if [[ -d "$NETPLAN_DIR" ]] && command -v netplan >/dev/null 2>&1; then
        echo "netplan"
    elif [[ -f "$INTERFACES_FILE" ]]; then
        echo "interfaces"
    elif [[ -d "$NETWORKMANAGER_DIR" ]] && systemctl is-active NetworkManager >/dev/null 2>&1; then
        echo "networkmanager"
    else
        echo "unknown"
    fi
}

# Get default gateway with fallback
get_default_gateway_smart() {
    local gateway=""
    
    # Try multiple methods to get gateway
    gateway=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -1)
    
    if [[ -z "$gateway" ]]; then
        gateway=$(route -n 2>/dev/null | awk '/^0.0.0.0/ {print $2}' | head -1)
    fi
    
    if [[ -z "$gateway" ]]; then
        gateway=$(netstat -rn 2>/dev/null | awk '/^0.0.0.0/ {print $2}' | head -1)
    fi
    
    echo "${gateway:-$DEFAULT_GATEWAY}"
}

# Get DNS servers
get_dns_servers() {
    local dns_servers=()
    
    # Try resolv.conf first
    if [[ -f /etc/resolv.conf ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^nameserver[[:space:]]+([0-9.]+) ]]; then
                dns_servers+=("${BASH_REMATCH[1]}")
            fi
        done < /etc/resolv.conf
    fi
    
    # Try systemd-resolved
    if [[ ${#dns_servers[@]} -eq 0 ]] && command -v resolvectl >/dev/null 2>&1; then
        local resolved_dns=$(resolvectl dns 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -2)
        if [[ -n "$resolved_dns" ]]; then
            dns_servers=($resolved_dns)
        fi
    fi
    
    # Use defaults if nothing found
    if [[ ${#dns_servers[@]} -eq 0 ]]; then
        dns_servers=("$DEFAULT_DNS_PRIMARY" "$DEFAULT_DNS_SECONDARY")
    fi
    
    printf '%s\n' "${dns_servers[@]}"
}

# =============================================================================
# INTERFACE MANAGEMENT FUNCTIONS
# =============================================================================

# List network interfaces with details
list_network_interfaces() {
    log_info "Listing network interfaces"
    
    echo -e "${CYAN}=== Network Interfaces ===${NC}"
    echo
    
    # Physical interfaces
    echo -e "${WHITE}Physical Interfaces:${NC}"
    for iface in /sys/class/net/*; do
        local name=$(basename "$iface")
        if [[ "$name" != "lo" ]] && [[ -e "$iface/device" ]]; then
            local state=$(cat "$iface/operstate" 2>/dev/null || echo "unknown")
            local mac=$(cat "$iface/address" 2>/dev/null || echo "unknown")
            local driver=$(readlink "$iface/device/driver" 2>/dev/null | xargs basename || echo "unknown")
            
            printf "  %-15s " "$name:"
            
            if [[ "$state" == "up" ]]; then
                echo -e "${GREEN}UP${NC}"
            else
                echo -e "${RED}$state${NC}"
            fi
            
            echo "    MAC: $mac"
            echo "    Driver: $driver"
            
            # Show IP addresses
            local ips=$(ip addr show "$name" 2>/dev/null | grep -oP 'inet \K[\d.]+' | paste -sd ' ')
            if [[ -n "$ips" ]]; then
                echo "    IPs: $ips"
            fi
            echo
        fi
    done
    
    # Virtual interfaces
    echo -e "${WHITE}Virtual Interfaces:${NC}"
    for iface in /sys/class/net/*; do
        local name=$(basename "$iface")
        if [[ "$name" != "lo" ]] && [[ ! -e "$iface/device" ]]; then
            local state=$(cat "$iface/operstate" 2>/dev/null || echo "unknown")
            printf "  %-15s %s\n" "$name:" "$state"
        fi
    done
    
    # Current routing table
    echo -e "\n${WHITE}Routing Table:${NC}"
    ip route show | head -10
    
    # DNS configuration
    echo -e "\n${WHITE}DNS Configuration:${NC}"
    get_dns_servers | while read dns; do
        echo "  $dns"
    done
}

# Configure interface based on network manager
configure_interface() {
    local interface="$1"
    local config="$2"
    local net_manager=$(detect_network_manager)
    
    log_info "Configuring interface $interface using $net_manager"
    
    case "$net_manager" in
        interfaces)
            configure_interface_debian "$interface" "$config"
            ;;
        netplan)
            configure_interface_netplan "$interface" "$config"
            ;;
        networkmanager)
            configure_interface_networkmanager "$interface" "$config"
            ;;
        *)
            log_error "Unknown network management system"
            return 1
            ;;
    esac
}

# Configure interface for Debian/Ubuntu (interfaces file)
configure_interface_debian() {
    local interface="$1"
    local config="$2"
    
    # Backup interfaces file
    backup_file "$INTERFACES_FILE"
    
    # Parse configuration
    local use_dhcp=$(echo "$config" | jq -r '.dhcp // false')
    
    if [[ "$use_dhcp" == "true" ]]; then
        # DHCP configuration
        cat >> "$INTERFACES_FILE" << EOF

auto $interface
iface $interface inet dhcp
EOF
    else
        # Static configuration
        local address=$(echo "$config" | jq -r '.address // ""')
        local netmask=$(echo "$config" | jq -r '.netmask // "255.255.255.0"')
        local gateway=$(echo "$config" | jq -r '.gateway // ""')
        local dns1=$(echo "$config" | jq -r '.dns[0] // ""')
        local dns2=$(echo "$config" | jq -r '.dns[1] // ""')
        local mtu=$(echo "$config" | jq -r '.mtu // "1500"')
        
        cat >> "$INTERFACES_FILE" << EOF

auto $interface
iface $interface inet static
    address $address
    netmask $netmask
EOF
        
        [[ -n "$gateway" ]] && echo "    gateway $gateway" >> "$INTERFACES_FILE"
        [[ -n "$dns1" ]] && echo "    dns-nameservers $dns1 $dns2" >> "$INTERFACES_FILE"
        [[ "$mtu" != "1500" ]] && echo "    mtu $mtu" >> "$INTERFACES_FILE"
    fi
    
    log_info "Interface $interface configured in $INTERFACES_FILE"
}

# Configure interface for Netplan
configure_interface_netplan() {
    local interface="$1"
    local config="$2"
    local netplan_file="$NETPLAN_DIR/50-flux-$interface.yaml"
    
    # Create netplan configuration
    local use_dhcp=$(echo "$config" | jq -r '.dhcp // false')
    
    cat > "/tmp/netplan_$interface.yaml" << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
EOF
    
    if [[ "$use_dhcp" == "true" ]]; then
        cat >> "/tmp/netplan_$interface.yaml" << EOF
      dhcp4: true
      dhcp6: false
EOF
    else
        local address=$(echo "$config" | jq -r '.address // ""')
        local prefix=$(echo "$config" | jq -r '.prefix // "24"')
        local gateway=$(echo "$config" | jq -r '.gateway // ""')
        local dns=$(echo "$config" | jq -r '.dns[]' 2>/dev/null | paste -sd ',')
        
        cat >> "/tmp/netplan_$interface.yaml" << EOF
      dhcp4: false
      dhcp6: false
      addresses:
        - $address/$prefix
EOF
        
        if [[ -n "$gateway" ]]; then
            cat >> "/tmp/netplan_$interface.yaml" << EOF
      routes:
        - to: default
          via: $gateway
EOF
        fi
        
        if [[ -n "$dns" ]]; then
            cat >> "/tmp/netplan_$interface.yaml" << EOF
      nameservers:
        addresses: [$dns]
EOF
        fi
    fi
    
    # Move configuration to place
    sudo mv "/tmp/netplan_$interface.yaml" "$netplan_file"
    sudo chmod 600 "$netplan_file"
    
    log_info "Interface $interface configured in $netplan_file"
    
    # Apply netplan configuration
    if prompt_yes_no "Apply netplan configuration now?" "y"; then
        sudo netplan apply
    fi
}

# =============================================================================
# VLAN MANAGEMENT
# =============================================================================

# Create VLAN interface
create_vlan_interface() {
    local parent_interface="$1"
    local vlan_id="$2"
    local vlan_config="$3"
    
    # Validate inputs
    if ! validate_interface "$parent_interface"; then
        log_error "Parent interface $parent_interface does not exist"
        return 1
    fi
    
    if ! validate_vlan "$vlan_id"; then
        log_error "Invalid VLAN ID: $vlan_id (must be 1-4094)"
        return 1
    fi
    
    # Check if 8021q module is loaded
    if ! lsmod | grep -q 8021q; then
        log_info "Loading 802.1Q VLAN module"
        sudo modprobe 8021q || {
            log_error "Failed to load 802.1Q module"
            return 1
        }
        
        # Make it persistent
        echo "8021q" | sudo tee -a /etc/modules >/dev/null
    fi
    
    local vlan_interface="${parent_interface}.${vlan_id}"
    local net_manager=$(detect_network_manager)
    
    case "$net_manager" in
        interfaces)
            # Add VLAN to interfaces file
            backup_file "$INTERFACES_FILE"
            
            # Add VLAN configuration
            echo "$vlan_config" | jq -r --arg parent "$parent_interface" --arg vid "$vlan_id" '
            "\nauto \($parent).\($vid)",
            "iface \($parent).\($vid) inet \(if .dhcp then "dhcp" else "static" end)",
            "    vlan-raw-device \($parent)",
            if .dhcp != true then
                "    address \(.address)",
                "    netmask \(.netmask // "255.255.255.0")",
                if .gateway then "    gateway \(.gateway)" else empty end,
                if .dns then "    dns-nameservers \(.dns | join(" "))" else empty end
            else empty end
            ' >> "$INTERFACES_FILE"
            ;;
            
        netplan)
            # Create netplan VLAN configuration
            local netplan_file="$NETPLAN_DIR/50-flux-vlan-$vlan_id.yaml"
            
            cat > "/tmp/vlan_$vlan_id.yaml" << EOF
network:
  version: 2
  renderer: networkd
  vlans:
    $vlan_interface:
      id: $vlan_id
      link: $parent_interface
EOF
            
            # Add IP configuration
            local use_dhcp=$(echo "$vlan_config" | jq -r '.dhcp // false')
            if [[ "$use_dhcp" == "true" ]]; then
                echo "      dhcp4: true" >> "/tmp/vlan_$vlan_id.yaml"
            else
                echo "$vlan_config" | jq -r '
                "      dhcp4: false",
                "      addresses:",
                "        - \(.address)/\(.prefix // "24")"
                ' >> "/tmp/vlan_$vlan_id.yaml"
            fi
            
            sudo mv "/tmp/vlan_$vlan_id.yaml" "$netplan_file"
            sudo chmod 600 "$netplan_file"
            ;;
    esac
    
    log_info "VLAN interface $vlan_interface created"
}

# =============================================================================
# INTERACTIVE CONFIGURATION
# =============================================================================

# Interactive interface configuration
configure_interface_interactive() {
    log_info "Starting interactive interface configuration"
    
    # Show available interfaces
    echo -e "${CYAN}Available network interfaces:${NC}"
    ip link show | grep -E '^[0-9]+:' | grep -v lo | awk '{print $2}' | sed 's/://g'
    echo
    
    # Select interface
    local interface=$(prompt_interface "Select interface to configure")
    
    # VLAN configuration
    local vlan_id=""
    if prompt_yes_no "Configure as VLAN interface?" "n"; then
        vlan_id=$(prompt_with_validation "Enter VLAN ID (1-4094)" "validate_vlan" "" "Invalid VLAN ID")
    fi
    
    # DHCP or static
    local config_json=""
    if prompt_yes_no "Use DHCP?" "n"; then
        config_json='{"dhcp": true}'
    else
        # Static configuration
        local ip_addr=$(prompt_ip "Enter IP address")
        local netmask=$(prompt_ip "Enter netmask" "$DEFAULT_NETMASK")
        
        # Calculate prefix from netmask
        local prefix=24
        case "$netmask" in
            255.255.255.0) prefix=24 ;;
            255.255.0.0) prefix=16 ;;
            255.0.0.0) prefix=8 ;;
            255.255.255.128) prefix=25 ;;
            255.255.255.192) prefix=26 ;;
            255.255.255.224) prefix=27 ;;
            255.255.255.240) prefix=28 ;;
            255.255.255.248) prefix=29 ;;
            255.255.255.252) prefix=30 ;;
        esac
        
        local gateway=$(prompt_ip "Enter gateway (or press Enter to detect)" "$(get_default_gateway_smart)")
        
        # DNS servers
        local dns_servers=($(get_dns_servers))
        local dns1=$(prompt_ip "Enter primary DNS" "${dns_servers[0]}")
        local dns2=$(prompt_ip "Enter secondary DNS" "${dns_servers[1]:-$DEFAULT_DNS_SECONDARY}")
        
        # MTU
        local mtu=$(prompt_with_validation "Enter MTU" "" "$DEFAULT_MTU" "Invalid MTU")
        
        # Build configuration JSON
        config_json=$(jq -n \
            --arg addr "$ip_addr" \
            --arg mask "$netmask" \
            --arg prefix "$prefix" \
            --arg gw "$gateway" \
            --arg dns1 "$dns1" \
            --arg dns2 "$dns2" \
            --arg mtu "$mtu" \
            '{
                dhcp: false,
                address: $addr,
                netmask: $mask,
                prefix: $prefix,
                gateway: $gw,
                dns: [$dns1, $dns2],
                mtu: $mtu
            }')
    fi
    
    # Apply configuration
    if [[ -n "$vlan_id" ]]; then
        create_vlan_interface "$interface" "$vlan_id" "$config_json"
    else
        configure_interface "$interface" "$config_json"
    fi
    
    # Restart networking
    if prompt_yes_no "Restart networking to apply changes?" "y"; then
        restart_networking
    fi
}

# =============================================================================
# NETWORK SERVICE MANAGEMENT
# =============================================================================

# Restart networking based on system
restart_networking() {
    local net_manager=$(detect_network_manager)
    
    log_info "Restarting networking ($net_manager)"
    
    case "$net_manager" in
        interfaces)
            sudo systemctl restart networking || sudo service networking restart
            ;;
        netplan)
            sudo netplan apply
            ;;
        networkmanager)
            sudo systemctl restart NetworkManager
            ;;
        *)
            log_error "Cannot restart networking - unknown system"
            return 1
            ;;
    esac
    
    log_info "Networking restarted"
}

# =============================================================================
# DIAGNOSTIC FUNCTIONS
# =============================================================================

# Network diagnostics
network_diagnostics() {
    echo -e "${CYAN}=== Network Diagnostics ===${NC}"
    
    # Connectivity tests
    echo -e "\n${WHITE}Connectivity Tests:${NC}"
    
    # Local gateway
    local gateway=$(get_default_gateway_smart)
    if [[ -n "$gateway" ]]; then
        echo -n "  Gateway ($gateway): "
        if ping -c 1 -W 2 "$gateway" >/dev/null 2>&1; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FAILED${NC}"
        fi
    fi
    
    # DNS resolution
    echo -n "  DNS (google.com): "
    if nslookup google.com >/dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
    fi
    
    # Internet connectivity
    echo -n "  Internet (8.8.8.8): "
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
    fi
    
    # Port checks
    echo -e "\n${WHITE}Common Ports:${NC}"
    local ports=("22:SSH" "80:HTTP" "443:HTTPS" "53:DNS")
    for port_info in "${ports[@]}"; do
        IFS=':' read -r port name <<< "$port_info"
        echo -n "  $name (port $port): "
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            echo -e "${GREEN}LISTENING${NC}"
        else
            echo -e "${YELLOW}NOT LISTENING${NC}"
        fi
    done
    
    # Network manager status
    echo -e "\n${WHITE}Network Manager:${NC} $(detect_network_manager)"
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

usage() {
    cat << EOF
Usage: $0 [options]

Network configuration and management module.

Options:
    -h, --help          Display this help message
    -l, --list          List network interfaces
    -c, --configure     Configure interface interactively
    -d, --diagnostics   Run network diagnostics
    -r, --restart       Restart networking
    --add-vlan IFACE ID Add VLAN interface
    --dhcp IFACE        Configure interface for DHCP
    --static IFACE IP   Configure static IP

Examples:
    $0 -l                          # List all interfaces
    $0 -c                          # Interactive configuration
    $0 --dhcp eth0                 # Configure eth0 for DHCP
    $0 --static eth0 10.0.1.100    # Configure static IP
    $0 --add-vlan eth0 100         # Create VLAN 100 on eth0
    $0 -d                          # Run diagnostics

EOF
    exit 0
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local action="list"
    local interface=""
    local ip_address=""
    local vlan_id=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -l|--list)
                action="list"
                shift
                ;;
            -c|--configure)
                action="configure"
                shift
                ;;
            -d|--diagnostics)
                action="diagnostics"
                shift
                ;;
            -r|--restart)
                action="restart"
                shift
                ;;
            --add-vlan)
                action="add-vlan"
                interface="$2"
                vlan_id="$3"
                shift 3
                ;;
            --dhcp)
                action="dhcp"
                interface="$2"
                shift 2
                ;;
            --static)
                action="static"
                interface="$2"
                ip_address="$3"
                shift 3
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    log_info "Flux network module started"
    
    # Execute action
    case "$action" in
        list)
            list_network_interfaces
            ;;
        configure)
            configure_interface_interactive
            ;;
        diagnostics)
            network_diagnostics
            ;;
        restart)
            restart_networking
            ;;
        add-vlan)
            if [[ -z "$interface" || -z "$vlan_id" ]]; then
                log_error "Interface and VLAN ID required"
                exit 1
            fi
            create_vlan_interface "$interface" "$vlan_id" '{"dhcp": true}'
            ;;
        dhcp)
            if [[ -z "$interface" ]]; then
                log_error "Interface name required"
                exit 1
            fi
            configure_interface "$interface" '{"dhcp": true}'
            ;;
        static)
            if [[ -z "$interface" || -z "$ip_address" ]]; then
                log_error "Interface and IP address required"
                exit 1
            fi
            # Simple static config
            local config=$(jq -n --arg ip "$ip_address" '{"dhcp": false, "address": $ip}')
            configure_interface "$interface" "$config"
            ;;
    esac
}

# Run main function
main "$@"