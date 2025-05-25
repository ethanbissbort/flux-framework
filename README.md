# Flux System Administration Framework

A modular, enterprise-grade Linux system configuration and hardening framework.

## Overview

Flux is a comprehensive system administration framework designed to automate and standardize Linux server configuration. Built with modularity and security in mind, it provides a consistent interface for system setup, hardening, and maintenance tasks.

### Key Features

- 🔧 **Modular Architecture**: Each function is a separate, independent module
- 🔒 **Security First**: Built-in security hardening and best practices
- 🚀 **Workflow Automation**: Pre-defined workflows for common scenarios
- 📝 **Comprehensive Logging**: Detailed logging and error tracking
- 🎯 **Interactive & Scriptable**: Works both interactively and in automation
- 🌐 **Multi-Distribution**: Supports Ubuntu, Debian, CentOS, RHEL, and derivatives

## Quick Start

```bash
# Clone the repository
git clone https://github.com/ethanbissbort/flux-framework.git
cd flux-framework

# Make scripts executable
chmod +x *.sh modules/*.sh

# Run essential setup
sudo ./main.sh workflow essential

# Or run interactive setup
sudo ./main.sh workflow complete
```

## Architecture

```
flux-framework/
├── main.sh                    # Core orchestrator
├── flux_helpers.sh            # Shared helper functions
├── modules/                   # Functional modules
│   ├── flux_network_module.sh     # Network configuration
│   ├── flux_hostname_module.sh    # Hostname management
│   ├── flux_user_module.sh        # User management
│   ├── flux_ssh_module.sh         # SSH hardening
│   ├── flux_firewall_module.sh    # Firewall configuration
│   ├── flux_update_module.sh      # System updates
│   ├── flux_certs_module.sh       # Certificate management
│   ├── flux_sysctl_module.sh      # Kernel parameters
│   ├── flux_zsh_module.sh         # ZSH installation
│   ├── flux_motd_module.sh        # MOTD customization
│   └── flux_netdata_module.sh     # Monitoring setup
├── config/                    # Configuration templates
├── docs/                      # Documentation
└── tests/                     # Test scripts
```

## Core Commands

### Framework Commands

```bash
# Show help
./main.sh help

# List available modules
./main.sh list

# Check system status
./main.sh status

# Show version
./main.sh version
```

### Module Operations

```bash
# Load and execute a module
./main.sh load MODULE_NAME [OPTIONS]

# Examples:
./main.sh load network -l          # List network interfaces
./main.sh load hostname -i          # Configure hostname interactively
./main.sh load user --menu          # User management menu
./main.sh load ssh -w               # SSH hardening wizard
```

### Workflows

Pre-defined workflows combine multiple modules for common scenarios:

```bash
# Essential setup (update, certs, sysctl, ssh)
./main.sh workflow essential

# Complete system setup
./main.sh workflow complete

# Security hardening only
./main.sh workflow security

# Development environment
./main.sh workflow development

# Monitoring setup
./main.sh workflow monitoring
```

## Module Reference

### System Update Module

Manages system updates and package installation.

```bash
# Full system update
./main.sh load update -f

# Include development packages
./main.sh load update -f -d

# Security updates only
./main.sh load update -s

# Configure automatic updates
./main.sh load update -a
```

### Network Module

Comprehensive network configuration management.

```bash
# List interfaces
./main.sh load network -l

# Configure interface interactively
./main.sh load network -c

# Configure static IP
./main.sh load network --static eth0 192.168.1.100

# Add VLAN
./main.sh load network --add-vlan eth0 100

# Network diagnostics
./main.sh load network -d
```

### Hostname Module

System hostname and FQDN configuration.

```bash
# Show current configuration
./main.sh load hostname -s

# Set hostname
./main.sh load hostname -n webserver

# Set FQDN
./main.sh load hostname -f webserver.example.com

# Interactive configuration
./main.sh load hostname -i
```

### User Management Module

Comprehensive user and group management.

```bash
# Interactive menu
./main.sh load user --menu

# Create admin user
./main.sh load user -a

# Create regular user
./main.sh load user -c john --fullname "John Doe" --groups "developers,docker"

# Add SSH key
./main.sh load user -k john ~/.ssh/id_rsa.pub

# Import GitHub keys
./main.sh load user -k john https://github.com/johndoe.keys
```

### SSH Module

SSH server hardening and configuration.

```bash
# Interactive hardening wizard
./main.sh load ssh -w

# Apply recommended hardening
./main.sh load ssh --harden

# Change SSH port
./main.sh load ssh -p 2222

# Run security audit
./main.sh load ssh -a

# Configure fail2ban
./main.sh load ssh --fail2ban
```

### Firewall Module

Unified firewall management for UFW and firewalld.

```bash
# Interactive setup wizard
./main.sh load firewall -w

# Apply security preset
./main.sh load firewall -p web-server

# Allow specific port
./main.sh load firewall -a 8080/tcp

# List rules
./main.sh load firewall -l

# Backup rules
./main.sh load firewall --backup
```

### Certificate Module

SSL/TLS certificate installation and management.

```bash
# Install from default repository
./main.sh load certs

# Install from custom repository
./main.sh load certs -c https://github.com/myorg/certificates

# List certificates without installing
./main.sh load certs -l

# Verify certificates
./main.sh load certs -v
```

### System Hardening Module

Kernel parameter tuning via sysctl.

```bash
# Apply hardening
./main.sh load sysctl

# Custom sysctl parameters
./main.sh load sysctl --custom /path/to/sysctl.conf
```

### ZSH Module

ZSH and Oh-My-Zsh installation.

```bash
# Install with default theme
./main.sh load zsh

# Install with Powerlevel10k
./main.sh load zsh -p

# Update plugins
./main.sh load zsh -u
```

### MOTD Module

Custom login message configuration.

```bash
# Interactive setup
./main.sh load motd -s

# Use specific ASCII art
./main.sh load motd -a flux-large -c blue

# Preview current MOTD
./main.sh load motd -p
```

### Monitoring Module

NetData monitoring system setup.

```bash
# Basic installation
./main.sh load netdata

# With cloud integration
./main.sh load netdata -c YOUR-CLAIM-TOKEN

# With SSL and external access
./main.sh load netdata -s -e --allowed-ips "10.0.0.0/8"
```

## Configuration

### Environment Variables

```bash
# Module directory (default: ./modules)
export FLUX_MODULES_DIR=/opt/flux/modules

# Configuration directory (default: ~/.config/flux)
export FLUX_CONFIG_DIR=/etc/flux

# Log file location (default: /var/log/flux-setup.log)
export LOGFILE=/var/log/flux.log

# Log level (0=debug, 1=info, 2=warn, 3=error)
export LOG_LEVEL=1
```

### Configuration File

Create `~/.config/flux/flux.conf`:

```bash
# Default settings
DEFAULT_SSH_PORT="2222"
DEFAULT_ADMIN_USER="fluxadmin"
GITHUB_USER="yourusername"
```

## Security Features

- **SSH Hardening**: Automated SSH configuration with security best practices
- **Firewall Management**: Unified interface for UFW and firewalld
- **Certificate Management**: Secure certificate installation and validation
- **Kernel Hardening**: Sysctl parameters for security
- **Access Control**: User and group management with SSH key support
- **Audit Logging**: Comprehensive logging of all operations

## Best Practices

1. **Always Backup**: Create backups before major changes
   ```bash
   ./main.sh load network --backup
   ./main.sh load firewall --backup
   ```

2. **Test First**: Use a test environment before production
   ```bash
   # Dry run where supported
   ./main.sh load update --check
   ```

3. **Use Workflows**: Leverage pre-defined workflows for consistency
   ```bash
   ./main.sh workflow essential
   ```

4. **Review Logs**: Check operation logs regularly
   ```bash
   tail -f /var/log/flux-setup.log
   ```

5. **Keep Updated**: Update the framework regularly
   ```bash
   git pull
   ./main.sh load update -f
   ```

## Troubleshooting

### Module Not Found

```bash
# List available modules
./main.sh list

# Check module directory
ls -la modules/
```

### Permission Issues

```bash
# Run with sudo for system operations
sudo ./main.sh load network -c

# Fix script permissions
chmod +x main.sh modules/*.sh
```

### Helper Library Issues

```bash
# Ensure helpers are in the correct location
ls -la flux_helpers.sh

# Check for sourcing errors in logs
grep "flux_helpers.sh not found" /var/log/flux-setup.log
```

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Module Structure**: Follow the existing module pattern
2. **Documentation**: Update docs for new features
3. **Testing**: Test on multiple distributions
4. **Code Style**: Follow the existing bash style guide
5. **Error Handling**: Use the helper functions for consistency

### Creating a New Module

```bash
#!/bin/bash
# flux_example_module.sh - Example module
# Version: 1.0.0
# Description of what this module does

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/flux_helpers.sh" || exit 1

# Set up error handling
setup_error_handling

# Module implementation...
```

## Support

- **Documentation**: See the `docs/` directory
- **Issues**: Submit via GitHub Issues
- **Updates**: Watch the repository for updates

## License

MIT License - See LICENSE file for details

## Acknowledgments

- Built with bash and love for Linux system administration
- Inspired by best practices from the DevOps community
- Thanks to all contributors and users

---

**Flux Framework** - Making Linux system administration modular, secure, and efficient.
