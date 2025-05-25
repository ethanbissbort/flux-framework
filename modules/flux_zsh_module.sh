#!/bin/bash

# flux-zsh.sh - ZSH and Oh-My-Zsh installation module
# Installs ZSH, Oh-My-Zsh, plugins, and themes

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

# Oh-My-Zsh configuration
readonly OMZ_INSTALL_URL="https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
readonly OMZ_DIR="$HOME/.oh-my-zsh"

# Popular plugins to install
readonly DEFAULT_PLUGINS=(
    "git"
    "docker"
    "docker-compose"
    "kubectl"
    "terraform"
    "ansible"
    "systemd"
    "ssh-agent"
    "gpg-agent"
    "colored-man-pages"
    "command-not-found"
    "common-aliases"
    "copyfile"
    "copydir"
    "history"
    "jsontools"
    "pip"
    "python"
    "rsync"
    "sudo"
    "systemadmin"
    "ubuntu"
    "web-search"
)

# External plugins to install
readonly EXTERNAL_PLUGINS=(
    "zsh-users/zsh-autosuggestions"
    "zsh-users/zsh-syntax-highlighting"
    "zsh-users/zsh-completions"
    "zsh-users/zsh-history-substring-search"
    "romkatv/powerlevel10k"
)

# Default theme
readonly DEFAULT_THEME="robbyrussell"
readonly POWERLINE_THEME="powerlevel10k/powerlevel10k"

# =============================================================================
# ZSH INSTALLATION FUNCTIONS
# =============================================================================

# Install ZSH package
install_zsh_package() {
    local distro=$(detect_distro)
    
    log_info "Installing ZSH package for $distro"
    
    # Check if ZSH is already installed
    if command -v zsh >/dev/null 2>&1; then
        local zsh_version=$(zsh --version | awk '{print $2}')
        log_info "ZSH is already installed (version: $zsh_version)"
        return 0
    fi
    
    case $distro in
        ubuntu|debian|mint|pop)
            sudo apt-get update
            if sudo apt-get install -y zsh curl git; then
                log_info "ZSH installed successfully via APT"
            else
                log_error "Failed to install ZSH via APT"
                return 1
            fi
            ;;
        centos|fedora|rhel|rocky|almalinux)
            local pkg_manager="yum"
            if command -v dnf >/dev/null 2>&1; then
                pkg_manager="dnf"
            fi
            
            if sudo $pkg_manager install -y zsh curl git; then
                log_info "ZSH installed successfully via $pkg_manager"
            else
                log_error "Failed to install ZSH via $pkg_manager"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported distribution: $distro"
            return 1
            ;;
    esac
    
    # Verify installation
    if command -v zsh >/dev/null 2>&1; then
        local zsh_version=$(zsh --version | awk '{print $2}')
        log_info "ZSH version $zsh_version installed successfully"
        return 0
    else
        log_error "ZSH installation verification failed"
        return 1
    fi
}

# Install Oh-My-Zsh
install_oh_my_zsh() {
    log_info "Installing Oh-My-Zsh"
    
    # Check if Oh-My-Zsh is already installed
    if [[ -d "$OMZ_DIR" ]]; then
        log_info "Oh-My-Zsh is already installed in $OMZ_DIR"
        if prompt_yes_no "Reinstall Oh-My-Zsh?" "n"; then
            log_info "Backing up existing Oh-My-Zsh installation"
            backup_file "$OMZ_DIR" "$HOME"
            rm -rf "$OMZ_DIR"
        else
            return 0
        fi
    fi
    
    # Download and install Oh-My-Zsh
    local installer="/tmp/install_omz.sh"
    if safe_download "$OMZ_INSTALL_URL" "$installer"; then
        chmod +x "$installer"
        
        # Install Oh-My-Zsh without switching to ZSH immediately
        log_info "Running Oh-My-Zsh installer"
        if RUNZSH=no CHSH=no sh "$installer" --unattended; then
            log_info "Oh-My-Zsh installed successfully"
            rm -f "$installer"
        else
            log_error "Oh-My-Zsh installation failed"
            rm -f "$installer"
            return 1
        fi
    else
        log_error "Failed to download Oh-My-Zsh installer"
        return 1
    fi
    
    # Verify installation
    if [[ -d "$OMZ_DIR" && -f "$OMZ_DIR/oh-my-zsh.sh" ]]; then
        log_info "Oh-My-Zsh installation verified"
        return 0
    else
        log_error "Oh-My-Zsh installation verification failed"
        return 1
    fi
}

# Install external ZSH plugins
install_external_plugins() {
    log_info "Installing external ZSH plugins"
    
    local plugins_dir="$OMZ_DIR/custom/plugins"
    local themes_dir="$OMZ_DIR/custom/themes"
    
    # Create directories if they don't exist
    mkdir -p "$plugins_dir" "$themes_dir"
    
    local installed_count=0
    local failed_count=0
    
    for plugin in "${EXTERNAL_PLUGINS[@]}"; do
        local plugin_name=$(basename "$plugin")
        local plugin_url="https://github.com/${plugin}.git"
        
        # Determine installation directory
        local install_dir
        if [[ "$plugin_name" == *"theme"* || "$plugin_name" == "powerlevel10k" ]]; then
            install_dir="$themes_dir/$plugin_name"
        else
            install_dir="$plugins_dir/$plugin_name"
        fi
        
        log_info "Installing plugin: $plugin_name"
        
        # Clone or update plugin
        if [[ -d "$install_dir" ]]; then
            log_info "Plugin $plugin_name already exists, updating..."
            if git -C "$install_dir" pull >/dev/null 2>&1; then
                log_info "✓ Updated: $plugin_name"
                ((installed_count++))
            else
                log_warn "✗ Failed to update: $plugin_name"
                ((failed_count++))
            fi
        else
            if git clone --depth=1 "$plugin_url" "$install_dir" >/dev/null 2>&1; then
                log_info "✓ Installed: $plugin_name"
                ((installed_count++))
            else
                log_warn "✗ Failed to install: $plugin_name"
                ((failed_count++))
            fi
        fi
    done
    
    log_info "Plugin installation completed: $installed_count successful, $failed_count failed"
    
    # Special setup for Powerlevel10k
    if [[ -d "$themes_dir/powerlevel10k" ]]; then
        log_info "Setting up Powerlevel10k theme"
        
        # Install recommended fonts if not present
        install_powerline_fonts
        
        log_info "Powerlevel10k theme ready (run 'p10k configure' after switching to ZSH)"
    fi
    
    return 0
}

# Install Powerline fonts
install_powerline_fonts() {
    log_info "Installing Powerline fonts"
    
    local fonts_dir="$HOME/.local/share/fonts"
    mkdir -p "$fonts_dir"
    
    # Download and install MesloLGS NF fonts (recommended for Powerlevel10k)
    local font_urls=(
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
    )
    
    for font_url in "${font_urls[@]}"; do
        local font_name=$(basename "$font_url" | sed 's/%20/ /g')
        local font_path="$fonts_dir/$font_name"
        
        if [[ ! -f "$font_path" ]]; then
            if safe_download "$font_url" "$font_path"; then
                log_info "✓ Downloaded font: $font_name"
            else
                log_warn "✗ Failed to download font: $font_name"
            fi
        else
            log_info "Font already exists: $font_name"
        fi
    done
    
    # Update font cache
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f -v "$fonts_dir" >/dev/null 2>&1
        log_info "Font cache updated"
    fi
    
    echo -e "${YELLOW}Note: You may need to configure your terminal to use 'MesloLGS NF' font${NC}"
}

# Configure ZSH with custom settings
configure_zsh() {
    local theme="${1:-$DEFAULT_THEME}"
    local custom_config_url="${2:-}"
    
    log_info "Configuring ZSH with theme: $theme"
    
    # Backup existing .zshrc if it exists
    if [[ -f "$HOME/.zshrc" ]]; then
        backup_file "$HOME/.zshrc"
    fi
    
    # Download custom .zshrc if URL provided
    if [[ -n "$custom_config_url" ]]; then
        log_info "Downloading custom .zshrc from: $custom_config_url"
        if safe_download "$custom_config_url" "$HOME/.zshrc"; then
            log_info "Custom .zshrc installed"
            return 0
        else
            log_warn "Failed to download custom .zshrc, creating default configuration"
        fi
    fi
    
    # Create default .zshrc configuration
    log_info "Creating default .zshrc configuration"
    
    cat > "$HOME/.zshrc" << EOF
# Flux ZSH Configuration
# Generated by flux-zsh.sh

# Oh-My-Zsh configuration
export ZSH="\$HOME/.oh-my-zsh"

# Theme configuration
ZSH_THEME="$theme"

# Plugin configuration
plugins=(
$(printf '    %s\n' "${DEFAULT_PLUGINS[@]}")
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    zsh-history-substring-search
)

# Oh-My-Zsh initialization
source \$ZSH/oh-my-zsh.sh

# User configuration

# Export environment variables
export LANG=en_US.UTF-8
export EDITOR='vim'
export ARCHFLAGS="-arch x86_64"

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias h='history'
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'

# System aliases
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias ps='ps aux'
alias top='htop'

# Network aliases
alias ports='netstat -tulanp'
alias listening='netstat -tulanp | grep LISTEN'

# Custom functions
function mkcd() {
    mkdir -p "\$1" && cd "\$1"
}

function extract() {
    if [ -f \$1 ] ; then
        case \$1 in
            *.tar.bz2)   tar xjf \$1     ;;
            *.tar.gz)    tar xzf \$1     ;;
            *.bz2)       bunzip2 \$1     ;;
            *.rar)       unrar e \$1     ;;
            *.gz)        gunzip \$1      ;;
            *.tar)       tar xf \$1      ;;
            *.tbz2)      tar xjf \$1     ;;
            *.tgz)       tar xzf \$1     ;;
            *.zip)       unzip \$1       ;;
            *.Z)         uncompress \$1  ;;
            *.7z)        7z x \$1        ;;
            *)     echo "'\$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'\$1' is not a valid file"
    fi
}

# History configuration
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_VERIFY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE

# Auto-completion configuration
autoload -U compinit
compinit

# Key bindings for history substring search
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Welcome message
if [[ -o interactive ]]; then
    echo "Welcome to Flux ZSH Configuration!"
    echo "Type 'flux-help' for available custom commands"
fi

# Custom Flux commands
function flux-help() {
    echo -e "\033[1;36mFlux ZSH Custom Commands:\033[0m"
    echo "  flux-help     - Show this help message"
    echo "  flux-update   - Update ZSH plugins and themes"
    echo "  flux-theme    - Change ZSH theme"
    echo "  mkcd <dir>    - Create directory and cd into it"
    echo "  extract <file> - Extract various archive formats"
}

function flux-update() {
    echo "Updating Oh-My-Zsh..."
    sh \$ZSH/tools/upgrade.sh
    
    echo "Updating custom plugins..."
    for plugin_dir in \$ZSH/custom/plugins/*/; do
        if [[ -d "\$plugin_dir/.git" ]]; then
            echo "Updating \$(basename \$plugin_dir)..."
            git -C "\$plugin_dir" pull
        fi
    done
    
    for theme_dir in \$ZSH/custom/themes/*/; do
        if [[ -d "\$theme_dir/.git" ]]; then
            echo "Updating \$(basename \$theme_dir)..."
            git -C "\$theme_dir" pull
        fi
    done
    
    echo "Update complete! Restart your shell to apply changes."
}

function flux-theme() {
    local new_theme=\$1
    if [[ -z "\$new_theme" ]]; then
        echo "Usage: flux-theme <theme_name>"
        echo "Available themes:"
        ls \$ZSH/themes/ | grep .zsh-theme | sed 's/.zsh-theme//'
        return 1
    fi
    
    sed -i "s/ZSH_THEME=.*/ZSH_THEME=\"\$new_theme\"/" \$HOME/.zshrc
    echo "Theme changed to \$new_theme. Restart your shell to apply."
}

# Load additional custom configurations
if [[ -f \$HOME/.zshrc.local ]]; then
    source \$HOME/.zshrc.local
fi

EOF
    
    log_info "Default .zshrc configuration created"
    
    # Set proper permissions
    chmod 644 "$HOME/.zshrc"
    
    return 0
}

# Set ZSH as default shell
set_default_shell() {
    local target_user="${1:-$(whoami)}"
    
    log_info "Setting ZSH as default shell for user: $target_user"
    
    # Check if ZSH is available
    local zsh_path=$(which zsh)
    if [[ -z "$zsh_path" ]]; then
        log_error "ZSH not found in PATH"
        return 1
    fi
    
    # Check if ZSH is in /etc/shells
    if ! grep -q "^$zsh_path$" /etc/shells; then
        log_info "Adding ZSH to /etc/shells"
        echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi
    
    # Don't change shell for root user unless explicitly requested
    if [[ "$target_user" == "root" ]]; then
        log_warn "Not changing shell for root user (security recommendation)"
        log_info "To manually change root shell, run: chsh -s $zsh_path root"
        return 0
    fi
    
    # Check current shell
    local current_shell=$(getent passwd "$target_user" | cut -d: -f7)
    if [[ "$current_shell" == "$zsh_path" ]]; then
        log_info "ZSH is already the default shell for $target_user"
        return 0
    fi
    
    # Change default shell
    if chsh -s "$zsh_path" "$target_user"; then
        log_info "Default shell changed to ZSH for $target_user"
        echo -e "${YELLOW}Note: You need to log out and log back in for the change to take effect${NC}"
        return 0
    else
        log_error "Failed to change default shell to ZSH"
        return 1
    fi
}

# Create ZSH configuration backup
backup_zsh_config() {
    log_info "Creating ZSH configuration backup"
    
    local backup_dir="$HOME/.config/flux-backups/zsh-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup ZSH configuration files
    local files_to_backup=(
        "$HOME/.zshrc"
        "$HOME/.zshrc.local"
        "$HOME/.zsh_history"
        "$HOME/.p10k.zsh"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [[ -f "$file" ]]; then
            cp "$file" "$backup_dir/"
            log_info "Backed up: $(basename "$file")"
        fi
    done
    
    # Backup Oh-My-Zsh custom directory
    if [[ -d "$OMZ_DIR/custom" ]]; then
        cp -r "$OMZ_DIR/custom" "$backup_dir/"
        log_info "Backed up: Oh-My-Zsh custom directory"
    fi
    
    log_info "ZSH configuration backed up to: $backup_dir"
    echo "$backup_dir"
}

# =============================================================================
# MAIN INSTALLATION FUNCTIONS
# =============================================================================

# Complete ZSH installation process
full_zsh_install() {
    local theme="${1:-$DEFAULT_THEME}"
    local custom_config_url="${2:-}"
    local set_as_default="${3:-true}"
    
    log_info "Starting complete ZSH installation process"
    
    # Create backup of existing configuration
    if [[ -f "$HOME/.zshrc" ]]; then
        backup_zsh_config
    fi
    
    # Install ZSH package
    if ! install_zsh_package; then
        log_error "Failed to install ZSH package"
        return 1
    fi
    
    # Install Oh-My-Zsh
    if ! install_oh_my_zsh; then
        log_error "Failed to install Oh-My-Zsh"
        return 1
    fi
    
    # Install external plugins
    if ! install_external_plugins; then
        log_warn "Some external plugins failed to install"
    fi
    
    # Configure ZSH
    if ! configure_zsh "$theme" "$custom_config_url"; then
        log_error "Failed to configure ZSH"
        return 1
    fi
    
    # Set as default shell
    if [[ "$set_as_default" == "true" ]]; then
        set_default_shell
    fi
    
    log_info "Complete ZSH installation process finished"
    
    # Show summary
    echo -e "\n${CYAN}=== ZSH Installation Summary ===${NC}"
    echo -e "${WHITE}✓ ZSH package installed${NC}"
    echo -e "${WHITE}✓ Oh-My-Zsh installed${NC}"
    echo -e "${WHITE}✓ External plugins installed${NC}"
    echo -e "${WHITE}✓ Configuration created${NC}"
    echo -e "${WHITE}✓ Powerline fonts installed${NC}"
    
    if [[ "$set_as_default" == "true" ]]; then
        echo -e "${WHITE}✓ Default shell configured${NC}"
    fi
    
    echo -e "\n${GREEN}ZSH installation completed successfully!${NC}"
    echo -e "${YELLOW}To start using ZSH, run: zsh${NC}"
    echo -e "${YELLOW}Or log out and log back in if you set it as default shell${NC}"
    
    if [[ "$theme" == "$POWERLINE_THEME" ]]; then
        echo -e "${YELLOW}For Powerlevel10k theme, run: p10k configure${NC}"
    fi
    
    return 0
}

# =============================================================================
# MAINTENANCE FUNCTIONS
# =============================================================================

# Update ZSH plugins and themes
update_zsh_plugins() {
    log_info "Updating ZSH plugins and themes"
    
    if [[ ! -d "$OMZ_DIR" ]]; then
        log_error "Oh-My-Zsh not found. Please install it first."
        return 1
    fi
    
    # Update Oh-My-Zsh
    log_info "Updating Oh-My-Zsh core"
    if [[ -f "$OMZ_DIR/tools/upgrade.sh" ]]; then
        env ZSH="$OMZ_DIR" sh "$OMZ_DIR/tools/upgrade.sh"
    fi
    
    # Update custom plugins
    local plugins_dir="$OMZ_DIR/custom/plugins"
    if [[ -d "$plugins_dir" ]]; then
        log_info "Updating custom plugins"
        for plugin_dir in "$plugins_dir"/*; do
            if [[ -d "$plugin_dir/.git" ]]; then
                local plugin_name=$(basename "$plugin_dir")
                log_info "Updating plugin: $plugin_name"
                if git -C "$plugin_dir" pull >/dev/null 2>&1; then
                    log_info "✓ Updated: $plugin_name"
                else
                    log_warn "✗ Failed to update: $plugin_name"
                fi
            fi
        done
    fi
    
    # Update custom themes
    local themes_dir="$OMZ_DIR/custom/themes"
    if [[ -d "$themes_dir" ]]; then
        log_info "Updating custom themes"
        for theme_dir in "$themes_dir"/*; do
            if [[ -d "$theme_dir/.git" ]]; then
                local theme_name=$(basename "$theme_dir")
                log_info "Updating theme: $theme_name"
                if git -C "$theme_dir" pull >/dev/null 2>&1; then
                    log_info "✓ Updated: $theme_name"
                else
                    log_warn "✗ Failed to update: $theme_name"
                fi
            fi
        done
    fi
    
    log_info "ZSH plugins and themes update completed"
}

# Uninstall ZSH and Oh-My-Zsh
uninstall_zsh() {
    log_warn "Starting ZSH uninstallation process"
    
    if ! prompt_yes_no "Are you sure you want to uninstall ZSH and Oh-My-Zsh?" "n"; then
        log_info "ZSH uninstallation cancelled"
        return 0
    fi
    
    # Create final backup
    if [[ -d "$OMZ_DIR" ]]; then
        backup_zsh_config
    fi
    
    # Change default shell back to bash
    local current_user=$(whoami)
    local current_shell=$(getent passwd "$current_user" | cut -d: -f7)
    
    if [[ "$current_shell" == *"zsh"* ]]; then
        log_info "Changing default shell back to bash"
        chsh -s /bin/bash "$current_user"
    fi
    
    # Remove Oh-My-Zsh
    if [[ -d "$OMZ_DIR" ]]; then
        log_info "Removing Oh-My-Zsh directory"
        rm -rf "$OMZ_DIR"
    fi
    
    # Remove ZSH configuration files
    local config_files=(
        "$HOME/.zshrc"
        "$HOME/.zshrc.local"
        "$HOME/.p10k.zsh"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            log_info "Removing: $file"
            rm -f "$file"
        fi
    done
    
    log_info "ZSH uninstallation completed"
    echo -e "${YELLOW}Note: ZSH package is still installed. Remove it manually if desired.${NC}"
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

usage() {
    cat << EOF
Usage: $0 [options]

ZSH and Oh-My-Zsh installation and configuration module.

Options:
    -h, --help          Display this help message
    -i, --install       Install ZSH and Oh-My-Zsh (default action)
    -t, --theme THEME   Set ZSH theme (default: $DEFAULT_THEME)
    -p, --powerlevel10k Use Powerlevel10k theme
    -c, --config URL    Custom .zshrc URL
    -n, --no-default    Don't set ZSH as default shell
    -u, --update        Update plugins and themes
    -b, --backup        Create configuration backup
    --uninstall         Uninstall ZSH and Oh-My-Zsh
    --fonts-only        Install Powerline fonts only

Examples:
    $0                          # Install with default theme
    $0 -p                       # Install with Powerlevel10k theme
    $0 -t agnoster              # Install with agnoster theme
    $0 -c https://my.zshrc      # Install with custom config
    $0 -u                       # Update plugins and themes
    $0 --fonts-only             # Install fonts only

Available themes: robbyrussell, agnoster, powerlevel10k, random, etc.
EOF
    exit 0
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local install_mode=true
    local theme="$DEFAULT_THEME"
    local custom_config_url=""
    local set_as_default=true
    local update_mode=false
    local backup_mode=false
    local uninstall_mode=false
    local fonts_only=false
    
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
            -t|--theme)
                theme="$2"
                shift 2
                ;;
            -p|--powerlevel10k)
                theme="$POWERLINE_THEME"
                shift
                ;;
            -c|--config)
                custom_config_url="$2"
                shift 2
                ;;
            -n|--no-default)
                set_as_default=false
                shift
                ;;
            -u|--update)
                update_mode=true
                install_mode=false
                shift
                ;;
            -b|--backup)
                backup_mode=true
                install_mode=false
                shift
                ;;
            --uninstall)
                uninstall_mode=true
                install_mode=false
                shift
                ;;
            --fonts-only)
                fonts_only=true
                install_mode=false
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    log_info "Flux ZSH module started"
    
    # Handle specific modes
    if [[ "$fonts_only" == true ]]; then
        install_powerline_fonts
        exit $?
    fi
    
    if [[ "$backup_mode" == true ]]; then
        backup_zsh_config
        exit $?
    fi
    
    if [[ "$update_mode" == true ]]; then
        update_zsh_plugins
        exit $?
    fi
    
    if [[ "$uninstall_mode" == true ]]; then
        uninstall_zsh
        exit $?
    fi
    
    if [[ "$install_mode" == true ]]; then
        full_zsh_install "$theme" "$custom_config_url" "$set_as_default"
        exit $?
    fi
    
    # Default action is install
    full_zsh_install "$theme" "$custom_config_url" "$set_as_default"
}

# Run main function with all arguments
main "$@"