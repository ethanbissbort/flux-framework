#!/bin/bash

# flux_user_module.sh - User management module
# Version: 1.0.0
# Manages system users, groups, and SSH access

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

# Default settings
readonly DEFAULT_SHELL="/bin/bash"
readonly DEFAULT_ADMIN_USER="fluxadmin"
readonly DEFAULT_ADMIN_GROUPS="sudo,adm,systemd-journal"
readonly SSH_DIR_PERMS="700"
readonly SSH_KEY_PERMS="600"
readonly SSH_PUB_PERMS="644"

# User home directories
readonly DEFAULT_HOME_BASE="/home"
readonly DEFAULT_SKEL="/etc/skel"

# =============================================================================
# USER MANAGEMENT FUNCTIONS
# =============================================================================

# Check if user exists
user_exists() {
    local username="$1"
    id "$username" &>/dev/null
}

# Check if group exists
group_exists() {
    local groupname="$1"
    getent group "$groupname" &>/dev/null
}

# Validate username
validate_username() {
    local username="$1"
    
    # Check length (1-32 characters)
    if [[ ${#username} -lt 1 || ${#username} -gt 32 ]]; then
        echo "Username must be 1-32 characters long"
        return 1
    fi
    
    # Check format (lowercase letters, numbers, dash, underscore)
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo "Username must start with lowercase letter or underscore, followed by lowercase letters, numbers, dash, or underscore"
        return 1
    fi
    
    # Check for reserved names
    local reserved_names=("root" "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail" "news" "uucp" "proxy" "www-data" "backup" "list" "irc" "gnats" "nobody")
    for reserved in "${reserved_names[@]}"; do
        if [[ "$username" == "$reserved" ]]; then
            echo "Username '$username' is reserved"
            return 1
        fi
    done
    
    return 0
}

# Create user
create_user() {
    local username="$1"
    local fullname="${2:-}"
    local shell="${3:-$DEFAULT_SHELL}"
    local home_dir="${4:-$DEFAULT_HOME_BASE/$username}"
    local create_home="${5:-true}"
    local system_user="${6:-false}"
    
    log_info "Creating user: $username"
    
    # Validate username
    local validation_error=$(validate_username "$username")
    if [[ $? -ne 0 ]]; then
        log_error "Invalid username: $validation_error"
        return 1
    fi
    
    # Check if user already exists
    if user_exists "$username"; then
        log_warn "User $username already exists"
        return 2
    fi
    
    # Build useradd command
    local useradd_cmd=(sudo useradd)
    
    # Add options
    [[ "$create_home" == "true" ]] && useradd_cmd+=(-m) || useradd_cmd+=(-M)
    [[ "$system_user" == "true" ]] && useradd_cmd+=(-r)
    [[ -n "$fullname" ]] && useradd_cmd+=(-c "$fullname")
    [[ -n "$shell" ]] && useradd_cmd+=(-s "$shell")
    [[ -n "$home_dir" ]] && useradd_cmd+=(-d "$home_dir")
    
    # Add username
    useradd_cmd+=("$username")
    
    # Create user
    if "${useradd_cmd[@]}"; then
        log_info "User $username created successfully"
        
        # Set up home directory permissions
        if [[ "$create_home" == "true" && -d "$home_dir" ]]; then
            sudo chmod 750 "$home_dir"
            sudo chown "$username:$username" "$home_dir"
        fi
        
        return 0
    else
        log_error "Failed to create user $username"
        return 1
    fi
}

# Delete user
delete_user() {
    local username="$1"
    local remove_home="${2:-false}"
    local backup_home="${3:-true}"
    
    log_info "Deleting user: $username"
    
    # Check if user exists
    if ! user_exists "$username"; then
        log_error "User $username does not exist"
        return 1
    fi
    
    # Prevent deletion of current user
    if [[ "$username" == "$(whoami)" ]]; then
        log_error "Cannot delete current user"
        return 1
    fi
    
    # Get user info before deletion
    local user_home=$(getent passwd "$username" | cut -d: -f6)
    
    # Backup home directory if requested
    if [[ "$backup_home" == "true" && -d "$user_home" ]]; then
        local backup_dir="/var/backups/users"
        sudo mkdir -p "$backup_dir"
        local backup_file="$backup_dir/${username}_home_$(date +%Y%m%d_%H%M%S).tar.gz"
        
        log_info "Backing up home directory to: $backup_file"
        sudo tar -czf "$backup_file" -C "$(dirname "$user_home")" "$(basename "$user_home")"
    fi
    
    # Kill user processes
    log_info "Terminating user processes"
    sudo pkill -u "$username" 2>/dev/null || true
    
    # Delete user
    local userdel_cmd=(sudo userdel)
    [[ "$remove_home" == "true" ]] && userdel_cmd+=(-r)
    userdel_cmd+=("$username")
    
    if "${userdel_cmd[@]}"; then
        log_info "User $username deleted successfully"
        return 0
    else
        log_error "Failed to delete user $username"
        return 1
    fi
}

# Modify user
modify_user() {
    local username="$1"
    shift
    
    log_info "Modifying user: $username"
    
    # Check if user exists
    if ! user_exists "$username"; then
        log_error "User $username does not exist"
        return 1
    fi
    
    # Parse modification options
    local new_shell=""
    local new_fullname=""
    local new_home=""
    local lock_user=false
    local unlock_user=false
    local expire_date=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --shell)
                new_shell="$2"
                shift 2
                ;;
            --fullname)
                new_fullname="$2"
                shift 2
                ;;
            --home)
                new_home="$2"
                shift 2
                ;;
            --lock)
                lock_user=true
                shift
                ;;
            --unlock)
                unlock_user=true
                shift
                ;;
            --expire)
                expire_date="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    # Apply modifications
    if [[ -n "$new_shell" ]]; then
        log_info "Changing shell to: $new_shell"
        sudo usermod -s "$new_shell" "$username"
    fi
    
    if [[ -n "$new_fullname" ]]; then
        log_info "Changing full name to: $new_fullname"
        sudo usermod -c "$new_fullname" "$username"
    fi
    
    if [[ -n "$new_home" ]]; then
        log_info "Changing home directory to: $new_home"
        sudo usermod -d "$new_home" -m "$username"
    fi
    
    if [[ "$lock_user" == "true" ]]; then
        log_info "Locking user account"
        sudo usermod -L "$username"
    fi
    
    if [[ "$unlock_user" == "true" ]]; then
        log_info "Unlocking user account"
        sudo usermod -U "$username"
    fi
    
    if [[ -n "$expire_date" ]]; then
        log_info "Setting expiration date to: $expire_date"
        sudo usermod -e "$expire_date" "$username"
    fi
    
    log_info "User $username modified successfully"
}

# =============================================================================
# GROUP MANAGEMENT FUNCTIONS
# =============================================================================

# Add user to groups
add_user_to_groups() {
    local username="$1"
    local groups="$2"
    
    log_info "Adding user $username to groups: $groups"
    
    # Check if user exists
    if ! user_exists "$username"; then
        log_error "User $username does not exist"
        return 1
    fi
    
    # Parse groups
    IFS=',' read -ra group_array <<< "$groups"
    
    local added_groups=()
    local failed_groups=()
    
    for group in "${group_array[@]}"; do
        group=$(echo "$group" | xargs)  # Trim whitespace
        
        # Create group if it doesn't exist (except for system groups)
        if ! group_exists "$group"; then
            if [[ "$group" =~ ^(sudo|wheel|adm|systemd-journal|docker)$ ]]; then
                log_warn "System group $group does not exist"
                failed_groups+=("$group")
                continue
            else
                log_info "Creating group: $group"
                sudo groupadd "$group"
            fi
        fi
        
        # Add user to group
        if sudo usermod -a -G "$group" "$username"; then
            added_groups+=("$group")
        else
            failed_groups+=("$group")
        fi
    done
    
    # Report results
    if [[ ${#added_groups[@]} -gt 0 ]]; then
        log_info "Added to groups: ${added_groups[*]}"
    fi
    
    if [[ ${#failed_groups[@]} -gt 0 ]]; then
        log_warn "Failed to add to groups: ${failed_groups[*]}"
        return 1
    fi
    
    return 0
}

# Remove user from groups
remove_user_from_groups() {
    local username="$1"
    local groups="$2"
    
    log_info "Removing user $username from groups: $groups"
    
    # Check if user exists
    if ! user_exists "$username"; then
        log_error "User $username does not exist"
        return 1
    fi
    
    # Get current groups
    local current_groups=$(groups "$username" | cut -d: -f2 | xargs)
    
    # Parse groups to remove
    IFS=',' read -ra remove_groups <<< "$groups"
    
    # Build new group list
    local new_groups=()
    for group in $current_groups; do
        local keep=true
        for remove_group in "${remove_groups[@]}"; do
            remove_group=$(echo "$remove_group" | xargs)
            if [[ "$group" == "$remove_group" ]]; then
                keep=false
                break
            fi
        done
        [[ "$keep" == "true" ]] && new_groups+=("$group")
    done
    
    # Apply new group list
    local new_groups_str=$(IFS=,; echo "${new_groups[*]}")
    sudo usermod -G "$new_groups_str" "$username"
    
    log_info "User groups updated"
}

# =============================================================================
# SSH KEY MANAGEMENT
# =============================================================================

# Setup SSH directory for user
setup_ssh_directory() {
    local username="$1"
    local user_home="${2:-$(getent passwd "$username" | cut -d: -f6)}"
    
    log_info "Setting up SSH directory for user: $username"
    
    local ssh_dir="$user_home/.ssh"
    
    # Create .ssh directory
    sudo mkdir -p "$ssh_dir"
    
    # Set ownership and permissions
    sudo chown "$username:$username" "$ssh_dir"
    sudo chmod "$SSH_DIR_PERMS" "$ssh_dir"
    
    # Create authorized_keys file if it doesn't exist
    local auth_keys="$ssh_dir/authorized_keys"
    if [[ ! -f "$auth_keys" ]]; then
        sudo touch "$auth_keys"
        sudo chown "$username:$username" "$auth_keys"
        sudo chmod "$SSH_KEY_PERMS" "$auth_keys"
    fi
    
    log_info "SSH directory configured"
}

# Add SSH key for user
add_ssh_key() {
    local username="$1"
    local key_source="$2"
    local key_comment="${3:-}"
    
    log_info "Adding SSH key for user: $username"
    
    # Check if user exists
    if ! user_exists "$username"; then
        log_error "User $username does not exist"
        return 1
    fi
    
    # Get user home directory
    local user_home=$(getent passwd "$username" | cut -d: -f6)
    setup_ssh_directory "$username" "$user_home"
    
    local auth_keys="$user_home/.ssh/authorized_keys"
    local key_content=""
    
    # Determine key source type
    if [[ "$key_source" =~ ^https://github.com/.* ]]; then
        # GitHub keys
        local github_user=$(echo "$key_source" | sed 's|https://github.com/||' | sed 's|.keys$||')
        log_info "Fetching SSH keys from GitHub user: $github_user"
        
        local temp_keys="/tmp/github_keys_$$"
        if safe_download "https://github.com/${github_user}.keys" "$temp_keys"; then
            key_content=$(cat "$temp_keys")
            rm -f "$temp_keys"
        else
            log_error "Failed to download GitHub keys"
            return 1
        fi
    elif [[ -f "$key_source" ]]; then
        # File path
        key_content=$(cat "$key_source")
    else
        # Direct key content
        key_content="$key_source"
    fi
    
    # Validate SSH key format
    if ! echo "$key_content" | ssh-keygen -l -f - &>/dev/null; then
        log_error "Invalid SSH key format"
        return 1
    fi
    
    # Add comment if provided
    if [[ -n "$key_comment" ]]; then
        key_content="$key_content $key_comment"
    fi
    
    # Check if key already exists
    local key_fingerprint=$(echo "$key_content" | ssh-keygen -l -f - | awk '{print $2}')
    if sudo grep -q "$key_fingerprint" "$auth_keys" 2>/dev/null; then
        log_warn "SSH key already exists for user $username"
        return 0
    fi
    
    # Add key to authorized_keys
    echo "$key_content" | sudo tee -a "$auth_keys" >/dev/null
    
    # Fix permissions
    sudo chown "$username:$username" "$auth_keys"
    sudo chmod "$SSH_KEY_PERMS" "$auth_keys"
    
    log_info "SSH key added successfully"
}

# Generate SSH key pair for user
generate_ssh_keypair() {
    local username="$1"
    local key_type="${2:-ed25519}"
    local key_comment="${3:-$username@$(hostname)}"
    
    log_info "Generating SSH keypair for user: $username"
    
    # Check if user exists
    if ! user_exists "$username"; then
        log_error "User $username does not exist"
        return 1
    fi
    
    # Get user home directory
    local user_home=$(getent passwd "$username" | cut -d: -f6)
    setup_ssh_directory "$username" "$user_home"
    
    local ssh_dir="$user_home/.ssh"
    local key_file="$ssh_dir/id_$key_type"
    
    # Check if key already exists
    if [[ -f "$key_file" ]]; then
        log_warn "SSH key already exists: $key_file"
        if ! prompt_yes_no "Overwrite existing key?" "n"; then
            return 0
        fi
        backup_file "$key_file"
        backup_file "${key_file}.pub"
    fi
    
    # Generate key
    sudo -u "$username" ssh-keygen -t "$key_type" -f "$key_file" -C "$key_comment" -N ""
    
    # Set permissions
    sudo chmod "$SSH_KEY_PERMS" "$key_file"
    sudo chmod "$SSH_PUB_PERMS" "${key_file}.pub"
    
    log_info "SSH keypair generated successfully"
    
    # Display public key
    echo -e "\n${WHITE}Public key:${NC}"
    cat "${key_file}.pub"
}

# =============================================================================
# PASSWORD MANAGEMENT
# =============================================================================

# Set user password
set_user_password() {
    local username="$1"
    local password="${2:-}"
    local force_change="${3:-false}"
    
    log_info "Setting password for user: $username"
    
    # Check if user exists
    if ! user_exists "$username"; then
        log_error "User $username does not exist"
        return 1
    fi
    
    if [[ -n "$password" ]]; then
        # Set password non-interactively
        echo "$username:$password" | sudo chpasswd
    else
        # Set password interactively
        sudo passwd "$username"
    fi
    
    # Force password change on next login
    if [[ "$force_change" == "true" ]]; then
        log_info "Forcing password change on next login"
        sudo passwd -e "$username"
    fi
    
    log_info "Password set successfully"
}

# =============================================================================
# ADMIN USER FUNCTIONS
# =============================================================================

# Create admin user with full setup
create_admin_user() {
    local username="${1:-$DEFAULT_ADMIN_USER}"
    local fullname="${2:-System Administrator}"
    local groups="${3:-$DEFAULT_ADMIN_GROUPS}"
    local github_user="${4:-}"
    
    log_info "Creating admin user: $username"
    
    # Create user
    if create_user "$username" "$fullname"; then
        log_info "Admin user created"
    elif [[ $? -eq 2 ]]; then
        log_warn "Admin user already exists"
        if ! prompt_yes_no "Configure existing user?" "y"; then
            return 0
        fi
    else
        return 1
    fi
    
    # Add to admin groups
    add_user_to_groups "$username" "$groups"
    
    # Setup SSH
    setup_ssh_directory "$username"
    
    # Add GitHub SSH keys if provided
    if [[ -n "$github_user" ]]; then
        add_ssh_key "$username" "https://github.com/${github_user}.keys" "GitHub: $github_user"
    fi
    
    # Generate SSH keypair
    if prompt_yes_no "Generate SSH keypair for $username?" "y"; then
        generate_ssh_keypair "$username"
    fi
    
    # Set password
    echo -e "\n${YELLOW}Setting password for $username:${NC}"
    set_user_password "$username"
    
    # Configure sudo without password (optional)
    if prompt_yes_no "Allow sudo without password?" "n"; then
        echo "$username ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$username" >/dev/null
        sudo chmod 440 "/etc/sudoers.d/$username"
        log_info "Passwordless sudo configured"
    fi
    
    log_info "Admin user setup completed"
}

# =============================================================================
# USER LISTING AND INFO
# =============================================================================

# List system users
list_users() {
    local show_system="${1:-false}"
    local min_uid=1000
    
    [[ "$show_system" == "true" ]] && min_uid=0
    
    echo -e "${CYAN}=== System Users ===${NC}"
    echo
    
    # Header
    printf "%-20s %-8s %-8s %-25s %s\n" "Username" "UID" "GID" "Full Name" "Home Directory"
    printf "%-20s %-8s %-8s %-25s %s\n" "--------" "---" "---" "---------" "--------------"
    
    # List users
    while IFS=: read -r username password uid gid fullname home shell; do
        if [[ $uid -ge $min_uid ]]; then
            # Truncate fullname if too long
            if [[ ${#fullname} -gt 25 ]]; then
                fullname="${fullname:0:22}..."
            fi
            
            printf "%-20s %-8s %-8s %-25s %s\n" "$username" "$uid" "$gid" "$fullname" "$home"
        fi
    done < /etc/passwd | sort -t: -k3 -n
    
    echo
    
    # Show locked accounts
    echo -e "${WHITE}Account Status:${NC}"
    local locked_users=()
    while IFS=: read -r username password rest; do
        if [[ "$password" == "!" || "$password" == "*" || "$password" == "!!"  ]]; then
            local uid=$(id -u "$username" 2>/dev/null)
            if [[ -n "$uid" && $uid -ge $min_uid ]]; then
                locked_users+=("$username")
            fi
        fi
    done < /etc/shadow 2>/dev/null || true
    
    if [[ ${#locked_users[@]} -gt 0 ]]; then
        echo "  Locked accounts: ${locked_users[*]}"
    else
        echo "  All accounts are active"
    fi
}

# Get detailed user info
user_info() {
    local username="$1"
    
    if ! user_exists "$username"; then
        log_error "User $username does not exist"
        return 1
    fi
    
    echo -e "${CYAN}=== User Information: $username ===${NC}"
    
    # Basic info
    local user_info=$(getent passwd "$username")
    IFS=: read -r uname x uid gid fullname home shell <<< "$user_info"
    
    echo -e "\n${WHITE}Basic Information:${NC}"
    echo "  Username: $uname"
    echo "  UID: $uid"
    echo "  GID: $gid"
    echo "  Full Name: $fullname"
    echo "  Home Directory: $home"
    echo "  Shell: $shell"
    
    # Groups
    echo -e "\n${WHITE}Groups:${NC}"
    local user_groups=$(groups "$username" | cut -d: -f2)
    echo "  $user_groups"
    
    # Account status
    echo -e "\n${WHITE}Account Status:${NC}"
    local shadow_info=$(sudo getent shadow "$username")
    if [[ -n "$shadow_info" ]]; then
        IFS=: read -r s_user s_pass s_lastchange s_min s_max s_warn s_inactive s_expire rest <<< "$shadow_info"
        
        # Check if account is locked
        if [[ "$s_pass" == "!" || "$s_pass" == "*" || "$s_pass" == "!!" ]]; then
            echo "  Status: Locked"
        else
            echo "  Status: Active"
        fi
        
        # Password age
        if [[ "$s_lastchange" != "" && "$s_lastchange" != "0" ]]; then
            local last_change_date=$(date -d "1970-01-01 $s_lastchange days" +%Y-%m-%d 2>/dev/null || echo "Unknown")
            echo "  Password Last Changed: $last_change_date"
        fi
        
        # Account expiration
        if [[ -n "$s_expire" && "$s_expire" != "" && "$s_expire" != "99999" ]]; then
            local expire_date=$(date -d "1970-01-01 $s_expire days" +%Y-%m-%d 2>/dev/null || echo "Unknown")
            echo "  Account Expires: $expire_date"
        fi
    fi
    
    # SSH keys
    echo -e "\n${WHITE}SSH Access:${NC}"
    local ssh_dir="$home/.ssh"
    if [[ -d "$ssh_dir" ]]; then
        # Authorized keys
        local auth_keys="$ssh_dir/authorized_keys"
        if [[ -f "$auth_keys" ]]; then
            local key_count=$(sudo grep -c "^ssh-" "$auth_keys" 2>/dev/null || echo "0")
            echo "  Authorized Keys: $key_count"
        else
            echo "  Authorized Keys: None"
        fi
        
        # User's own keys
        local key_files=$(sudo ls "$ssh_dir"/id_* 2>/dev/null | grep -v ".pub$" | wc -l)
        echo "  SSH Keypairs: $key_files"
    else
        echo "  SSH not configured"
    fi
    
    # Last login
    echo -e "\n${WHITE}Last Login:${NC}"
    local last_login=$(last -n 1 "$username" 2>/dev/null | head -1)
    if [[ -n "$last_login" && ! "$last_login" =~ "wtmp begins" ]]; then
        echo "  $last_login"
    else
        echo "  No login records found"
    fi
}

# =============================================================================
# INTERACTIVE FUNCTIONS
# =============================================================================

# Interactive user management menu
user_management_menu() {
    while true; do
        echo -e "\n${CYAN}=== User Management Menu ===${NC}"
        echo "1) List users"
        echo "2) Create user"
        echo "3) Create admin user"
        echo "4) Modify user"
        echo "5) Delete user"
        echo "6) User information"
        echo "7) Manage SSH keys"
        echo "8) Change password"
        echo "9) Exit"
        echo
        
        local choice
        read -p "Select option [1-9]: " choice
        
        case "$choice" in
            1)
                list_users
                ;;
            2)
                local username=$(prompt_with_validation "Enter username" "validate_username" "" "")
                if [[ -n "$username" ]]; then
                    read -p "Enter full name: " fullname
                    create_user "$username" "$fullname"
                    
                    if prompt_yes_no "Add to groups?" "y"; then
                        read -p "Enter groups (comma-separated): " groups
                        add_user_to_groups "$username" "$groups"
                    fi
                    
                    if prompt_yes_no "Set password now?" "y"; then
                        set_user_password "$username"
                    fi
                fi
                ;;
            3)
                read -p "Enter admin username [$DEFAULT_ADMIN_USER]: " admin_user
                admin_user="${admin_user:-$DEFAULT_ADMIN_USER}"
                read -p "Enter full name: " fullname
                read -p "Enter GitHub username (for SSH keys): " github_user
                create_admin_user "$admin_user" "$fullname" "$DEFAULT_ADMIN_GROUPS" "$github_user"
                ;;
            4)
                read -p "Enter username to modify: " username
                if user_exists "$username"; then
                    echo "Modify options:"
                    echo "  1) Change shell"
                    echo "  2) Change full name"
                    echo "  3) Lock account"
                    echo "  4) Unlock account"
                    read -p "Select option: " mod_choice
                    
                    case "$mod_choice" in
                        1)
                            read -p "Enter new shell: " new_shell
                            modify_user "$username" --shell "$new_shell"
                            ;;
                        2)
                            read -p "Enter new full name: " new_name
                            modify_user "$username" --fullname "$new_name"
                            ;;
                        3)
                            modify_user "$username" --lock
                            ;;
                        4)
                            modify_user "$username" --unlock
                            ;;
                    esac
                fi
                ;;
            5)
                read -p "Enter username to delete: " username
                if user_exists "$username"; then
                    if prompt_yes_no "Remove home directory?" "n"; then
                        delete_user "$username" true true
                    else
                        delete_user "$username" false true
                    fi
                fi
                ;;
            6)
                read -p "Enter username: " username
                user_info "$username"
                ;;
            7)
                read -p "Enter username: " username
                if user_exists "$username"; then
                    echo "SSH key options:"
                    echo "  1) Add SSH key"
                    echo "  2) Add GitHub keys"
                    echo "  3) Generate keypair"
                    read -p "Select option: " ssh_choice
                    
                    case "$ssh_choice" in
                        1)
                            read -p "Enter SSH public key or file path: " key_source
                            add_ssh_key "$username" "$key_source"
                            ;;
                        2)
                            read -p "Enter GitHub username: " github_user
                            add_ssh_key "$username" "https://github.com/${github_user}.keys"
                            ;;
                        3)
                            generate_ssh_keypair "$username"
                            ;;
                    esac
                fi
                ;;
            8)
                read -p "Enter username: " username
                if user_exists "$username"; then
                    set_user_password "$username"
                fi
                ;;
            9)
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

usage() {
    cat << EOF
Usage: $0 [options]

User management module for creating and managing system users.

Options:
    -h, --help                      Display this help message
    -l, --list                      List users
    -i, --info USERNAME             Show user information
    -c, --create USERNAME           Create new user
    -a, --admin [USERNAME]          Create admin user
    -d, --delete USERNAME           Delete user
    -m, --modify USERNAME [OPTIONS] Modify user
    -k, --add-key USERNAME KEY      Add SSH key
    -p, --password USERNAME         Set user password
    --menu                          Interactive menu

Create Options:
    --fullname "Full Name"          Set user's full name
    --shell /bin/bash              Set user's shell
    --groups "group1,group2"        Add user to groups

Modify Options:
    --shell SHELL                   Change shell
    --fullname "Name"              Change full name
    --lock                         Lock account
    --unlock                       Unlock account

Examples:
    $0 -l                          # List all users
    $0 -c john --fullname "John Doe" --groups "users,docker"
    $0 -a                          # Create default admin user
    $0 -k john ~/.ssh/id_rsa.pub   # Add SSH key
    $0 --menu                      # Interactive menu

EOF
    exit 0
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local action=""
    local username=""
    local extra_args=()
    
    # Parse primary command
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -l|--list)
                action="list"
                shift
                ;;
            -i|--info)
                action="info"
                username="$2"
                shift 2
                ;;
            -c|--create)
                action="create"
                username="$2"
                shift 2
                break
                ;;
            -a|--admin)
                action="admin"
                username="${2:-$DEFAULT_ADMIN_USER}"
                [[ "$2" != "--"* ]] && shift
                shift
                break
                ;;
            -d|--delete)
                action="delete"
                username="$2"
                shift 2
                ;;
            -m|--modify)
                action="modify"
                username="$2"
                shift 2
                break
                ;;
            -k|--add-key)
                action="add-key"
                username="$2"
                shift 2
                break
                ;;
            -p|--password)
                action="password"
                username="$2"
                shift 2
                ;;
            --menu)
                action="menu"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Collect remaining arguments
    extra_args=("$@")
    
    log_info "Flux user management module started"
    
    # Execute action
    case "$action" in
        list)
            list_users
            ;;
        info)
            if [[ -z "$username" ]]; then
                log_error "Username required"
                exit 1
            fi
            user_info "$username"
            ;;
        create)
            if [[ -z "$username" ]]; then
                log_error "Username required"
                exit 1
            fi
            
            # Parse create options
            local fullname=""
            local shell="$DEFAULT_SHELL"
            local groups=""
            
            while [[ ${#extra_args[@]} -gt 0 ]]; do
                case "${extra_args[0]}" in
                    --fullname)
                        fullname="${extra_args[1]}"
                        extra_args=("${extra_args[@]:2}")
                        ;;
                    --shell)
                        shell="${extra_args[1]}"
                        extra_args=("${extra_args[@]:2}")
                        ;;
                    --groups)
                        groups="${extra_args[1]}"
                        extra_args=("${extra_args[@]:2}")
                        ;;
                    *)
                        extra_args=("${extra_args[@]:1}")
                        ;;
                esac
            done
            
            create_user "$username" "$fullname" "$shell"
            
            if [[ -n "$groups" ]]; then
                add_user_to_groups "$username" "$groups"
            fi
            ;;
        admin)
            # Parse admin options
            local fullname=""
            local github_user=""
            
            while [[ ${#extra_args[@]} -gt 0 ]]; do
                case "${extra_args[0]}" in
                    --fullname)
                        fullname="${extra_args[1]}"
                        extra_args=("${extra_args[@]:2}")
                        ;;
                    --github)
                        github_user="${extra_args[1]}"
                        extra_args=("${extra_args[@]:2}")
                        ;;
                    *)
                        extra_args=("${extra_args[@]:1}")
                        ;;
                esac
            done
            
            create_admin_user "$username" "$fullname" "$DEFAULT_ADMIN_GROUPS" "$github_user"
            ;;
        delete)
            if [[ -z "$username" ]]; then
                log_error "Username required"
                exit 1
            fi
            if prompt_yes_no "Delete user $username?" "n"; then
                delete_user "$username" false true
            fi
            ;;
        modify)
            if [[ -z "$username" ]]; then
                log_error "Username required"
                exit 1
            fi
            modify_user "$username" "${extra_args[@]}"
            ;;
        add-key)
            if [[ -z "$username" || ${#extra_args[@]} -eq 0 ]]; then
                log_error "Username and key required"
                exit 1
            fi
            add_ssh_key "$username" "${extra_args[0]}"
            ;;
        password)
            if [[ -z "$username" ]]; then
                log_error "Username required"
                exit 1
            fi
            set_user_password "$username"
            ;;
        menu)
            user_management_menu
            ;;
        *)
            usage
            ;;
    esac
}

# Run main function
main "$@"
