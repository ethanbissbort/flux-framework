# Flux Scripts Usage Guide

## 📁 File Structure

Your Flux scripts should be organized as follows:

```
flux-scripts/
├── flux-helpers.sh      # Reusable helper functions (REQUIRED)
├── main.sh              # Main setup script
├── flux-certs.sh        # Certificate installation
├── flux-sysctl.sh       # System hardening (existing)
└── README.md            # This guide
```

## 🚀 Quick Start

### 1. Make Scripts Executable
```bash
chmod +x *.sh
```

### 2. Run Complete Setup
```bash
# Full automated setup
sudo ./main.sh --all

# Or step by step
sudo ./main.sh --update          # Update system first
sudo ./main.sh -n                # Change hostname
sudo ./main.sh -a                # Add network interface
sudo ./main.sh -s                # SSH hardening
```

### 3. Individual Components
```bash
# Install certificates only
./flux-certs.sh

# Apply sysctl hardening only
./flux-sysctl.sh

# Install ZSH and Oh-My-Zsh
./main.sh -z
```

## 📋 Available Functions

### Main Script (main.sh)

| Option | Function | Description |
|--------|----------|-------------|
| `--all` | Complete Setup | Runs all setup functions in sequence |
| `-n, --hostname` | Change Hostname | Set system hostname/FQDN |
| `-i, --interfaces` | List Interfaces | Display network interface info |
| `-a, --add-interface` | Add Interface | Configure new network interface |
| `-u, --user` | Add User | Create fluxadmin user |
| `-s, --ssh` | SSH Hardening | Secure SSH configuration |
| `-z, --zsh` | Install ZSH | Install ZSH and Oh-My-Zsh |
| `-m, --motd` | Custom MOTD | Setup custom login message |
| `-c, --certs` | Install Certs | Install trusted certificates |
| `-t, --sysctl` | System Hardening | Apply sysctl security settings |
| `-l, --locale` | Set Locale | Configure timezone and locale |
| `--update` | System Update | Update and upgrade packages |
| `--netdata` | NetData Setup | Install system monitoring |

### Certificate Script (flux-certs.sh)

| Option | Description |
|--------|-------------|
| `(default)` | Install certificates from default repo |
| `-l, --list` | List certificates without installing |
| `-v, --verify` | Verify certificate validity only |
| `-c, --cleanup` | Clean up temporary files |

## 🔧 Helper Functions Available

### Input Validation
- `validate_ip()` - Validate IP addresses (proper range checking)
- `validate_hostname()` - Validate hostname/FQDN format
- `validate_interface()` - Check if network interface exists
- `validate_vlan()` - Validate VLAN ID (1-4094)
- `validate_port()` - Validate port number (1-65535)

### User Input
- `prompt_yes_no()` - Yes/No prompts with defaults
- `prompt_ip()` - IP address input with validation
- `prompt_hostname()` - Hostname input with validation
- `prompt_interface()` - Network interface selection

### File Operations
- `backup_file()` - Create timestamped backups
- `safe_write_file()` - Write files with backup
- `safe_append_file()` - Append to files with backup

### Logging
- `log_info()` - Info messages (green)
- `log_warn()` - Warning messages (yellow)  
- `log_error()` - Error messages (red)
- `log_debug()` - Debug messages (cyan)

### Downloads
- `safe_download()` - Download with retries and verification
- `verify_checksum()` - Verify file checksums

### System Detection
- `detect_distro()` - Detect Linux distribution
- `is_root()` - Check if running as root
- `has_systemd()` - Check for systemd availability

## 💡 Usage Examples

### Interactive Network Setup
```bash
# Add network interface with prompts
sudo ./main.sh -a

# Example interaction:
# Enter Ethernet connection name: eth0
# Enter VLAN number (or press Enter): 100
# Enter Static IP address: 192.168.1.10
# Enter netmask [default: 255.255.0.0]: 255.255.255.0
```

### Automated Certificate Installation
```bash
# List certificates from custom repo
./flux-certs.sh -l https://github.com/myorg/certificates

# Install certificates
./flux-certs.sh https://github.com/myorg/certificates
```

### SSH Hardening with GitHub Keys
```bash
# Will prompt for GitHub username and SSH port
sudo ./main.sh -s

# Example interaction:
# Enter GitHub username: yourusername
# Enter SSH port [default: 2202]: 2222
```

### Complete System Setup
```bash
# Run full setup with prompts for each step
sudo ./main.sh --all

# Will ask yes/no for each function:
# Run initial_update_upgrade? [y/N]: y
# Run set_locale_and_timezone? [y/N]: y
# ... etc
```

## 🔍 Error Handling Features

### Automatic Backups
All configuration file changes automatically create timestamped backups:
```
/etc/ssh/sshd_config.backup_20250524_143022
/etc/network/interfaces.backup_20250524_143025
```

### Comprehensive Logging
All operations are logged to `/var/log/flux-setup.log`:
```
[2025-05-24 14:30:22] [INFO] Starting hostname configuration
[2025-05-24 14:30:25] [INFO] Hostname changed to server01.example.com
[2025-05-24 14:30:26] [WARN] Reboot will be needed: SSH configuration changed
```

### Reboot Management
Scripts track when reboots are needed and prompt at the end:
```
A system reboot is recommended to apply all changes.
Reboot now? [y/N]: n
Please reboot manually when convenient.
```

## 🛠️ Customization

### Environment Variables
Set these before running scripts:
```bash
export LOGFILE="/custom/path/flux.log"
export LOG_LEVEL=0  # 0=debug, 1=info, 2=warn, 3=error
```

### Custom Repositories
```bash
# Custom certificate repository
./flux-certs.sh https://github.com/myorg/custom-certs

# Custom configuration URLs
# Scripts will prompt for custom URLs when relevant
```

### Configuration Files
Helper functions support loading from config files:
```bash
# /etc/flux-config.conf
DEFAULT_GATEWAY="10.0.1.1"
DEFAULT_DNS="10.0.1.101"
GITHUB_USER="myusername"
```

## 🔧 Troubleshooting

### Common Issues

1. **Permission Errors**
   ```bash
   # Ensure scripts are executable and run with sudo when needed
   chmod +x *.sh
   sudo ./main.sh --option
   ```

2. **Helper Functions Not Found**
   ```bash
   # Ensure flux-helpers.sh is in the same directory
   ls -la flux-helpers.sh
   ```

3. **Network Interface Not Found**
   ```bash
   # List available interfaces first
   ./main.sh -i
   ip link show
   ```

4. **Certificate Installation Fails**
   ```bash
   # Verify certificates first
   ./flux-certs.sh -v
   ```

### Debug Mode
```bash
# Enable debug logging
export LOG_LEVEL=0
./main.sh --option
```

### Manual Cleanup
```bash
# Remove temporary files
rm -rf /tmp/flux-*
rm -rf /tmp/certificates

# View logs
tail -f /var/log/flux-setup.log
```

## 📚 Integration Tips

### Sourcing Helpers in Custom Scripts
```bash
#!/bin/bash
# my-custom-script.sh

source ./flux-helpers.sh

# Now you can use all helper functions
ip_addr=$(prompt_ip "Enter server IP")
log_info "Configuring server with IP: $ip_addr"
```

### Extending Functionality
Add your own functions to the helper library or create additional modules that source the helpers.

### CI/CD Integration
Scripts support non-interactive mode when input is piped:
```bash
echo -e "y\ny\ny\n" | sudo ./main.sh --all
```