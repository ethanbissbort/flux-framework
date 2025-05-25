# Flux Framework Migration Guide

## From v2.x to v3.0 - Modular Architecture

This guide helps you migrate from the monolithic Flux scripts to the new modular architecture.

## Overview of Changes

### Old Structure (v2.x)
```
flux-scripts/
├── main.sh              # Monolithic script with all functions
├── flux-certs.sh        # Certificate management
├── flux-sysctl.sh       # System hardening
├── flux-helpers.sh      # Helper functions
└── various other scripts...
```

### New Structure (v3.0)
```
flux-scripts/
├── main.sh                    # Core orchestrator only
├── flux_helpers.sh            # Enhanced helper library
├── modules/                   # All functional modules
│   ├── flux_network_module.sh
│   ├── flux_hostname_module.sh
│   ├── flux_user_module.sh
│   ├── flux_ssh_module.sh
│   ├── flux_firewall_module.sh
│   ├── flux_update_module.sh
│   ├── flux_certs_module.sh
│   ├── flux_sysctl_module.sh
│   ├── flux_zsh_module.sh
│   ├── flux_motd_module.sh
│   └── flux_netdata_module.sh
└── legacy/                    # Old scripts for compatibility
```

## Key Improvements

1. **Modular Design**: Each function is now a separate module
2. **Consistent Interface**: All modules follow the same patterns
3. **Better Error Handling**: Enhanced error handling and logging
4. **Improved CLI**: Standardized command-line interfaces
5. **Dynamic Loading**: Modules are discovered and loaded dynamically
6. **Workflows**: Pre-defined workflows for common tasks

## Migration Steps

### Step 1: Backup Current Setup

```bash
# Create backup directory
mkdir -p ~/flux-backup-$(date +%Y%m%d)

# Backup current scripts
cp -r /path/to/flux-scripts ~/flux-backup-$(date +%Y%m%d)/

# Backup configurations
sudo cp -r /etc/flux* ~/flux-backup-$(date +%Y%m%d)/
```

### Step 2: Install New Framework

```bash
# Clone or download new version
git clone https://github.com/yourusername/flux-scripts.git flux-v3

# Create modules directory
mkdir -p flux-v3/modules

# Move modules to proper location
mv flux-v3/flux_*_module.sh flux-v3/modules/

# Make scripts executable
chmod +x flux-v3/*.sh flux-v3/modules/*.sh
```

### Step 3: Update Command Usage

#### Old Commands → New Commands

**System Update:**
```bash
# Old
./main.sh --update

# New
./main.sh load update
# or with options
./main.sh load update -f -d  # Full update with dev packages
```

**Network Configuration:**
```bash
# Old
./main.sh -a  # Add interface interactively

# New
./main.sh load network -c  # Configure interface
./main.sh load network --static eth0 192.168.1.100
```

**Hostname Configuration:**
```bash
# Old
./main.sh -n  # Change hostname

# New
./main.sh load hostname -i  # Interactive
./main.sh load hostname -n webserver
./main.sh load hostname -f web.example.com
```

**User Management:**
```bash
# Old
./main.sh -u  # Add fluxadmin user

# New
./main.sh load user --menu  # Interactive menu
./main.sh load user -a  # Create admin user
./main.sh load user -c john --fullname "John Doe"
```

**SSH Hardening:**
```bash
# Old
./main.sh -s  # SSH hardening

# New
./main.sh load ssh -w  # Interactive wizard
./main.sh load ssh --harden  # Apply recommended settings
```

**Certificate Installation:**
```bash
# Old
./flux-certs.sh

# New
./main.sh load certs
./main.sh load certs -c https://github.com/myorg/certs
```

### Step 4: Use Workflows

The new framework includes pre-defined workflows:

```bash
# Essential setup (update, certs, sysctl, ssh)
./main.sh workflow essential

# Complete setup (all modules)
./main.sh workflow complete

# Security hardening
./main.sh workflow security

# Development environment
./main.sh workflow development
```

### Step 5: Update Scripts and Automation

If you have scripts that call Flux commands, update them:

```bash
#!/bin/bash
# Old automation script
./main.sh --update
./main.sh -n
./main.sh -a
./main.sh -s

# New automation script
./main.sh load update -f
./main.sh load hostname -i
./main.sh load network -c
./main.sh load ssh --harden
```

### Step 6: Configuration Migration

The new framework uses a configuration directory:

```bash
# Create config directory
mkdir -p ~/.config/flux

# Migrate any custom configurations
cp /etc/flux.conf ~/.config/flux/flux.conf 2>/dev/null || true
```

## Module-Specific Migration

### Network Module

The network functionality is now a dedicated module with enhanced features:

- Supports multiple network managers (interfaces, netplan, NetworkManager)
- VLAN support improved
- Better validation and error handling

```bash
# View network status
./main.sh load network -l

# Run diagnostics
./main.sh load network -d
```

### User Module

User management is now more comprehensive:

```bash
# Interactive user management
./main.sh load user --menu

# Create user with groups
./main.sh load user -c alice --fullname "Alice Smith" --groups "docker,developers"

# SSH key management
./main.sh load user -k alice ~/.ssh/id_rsa.pub
./main.sh load user --github alice alicegithub
```

### SSH Module

SSH hardening now includes:

- Security audit functionality
- fail2ban integration
- Automatic GitHub key import

```bash
# Run security audit
./main.sh load ssh -a

# Configure fail2ban
./main.sh load ssh --fail2ban
```

### Firewall Module

New firewall module supports both UFW and firewalld:

```bash
# Interactive setup
./main.sh load firewall -w

# Apply preset
./main.sh load firewall -p web-server

# Backup rules
./main.sh load firewall --backup
```

## Compatibility Notes

### Breaking Changes

1. **Command Structure**: All commands now use `load MODULE` format
2. **Options**: Some option flags have changed
3. **Output Format**: More structured output with consistent coloring
4. **Error Codes**: Standardized error codes across modules

### Deprecated Features

The following features are deprecated:

1. Direct function calls in main.sh
2. Legacy network interface syntax
3. Combined operations (use workflows instead)

### Environment Variables

New environment variables:

```bash
# Module directory (default: ./modules)
export FLUX_MODULES_DIR=/opt/flux/modules

# Configuration directory (default: ~/.config/flux)
export FLUX_CONFIG_DIR=/etc/flux

# Log file location
export LOGFILE=/var/log/flux.log

# Log level (0=debug, 1=info, 2=warn, 3=error)
export LOG_LEVEL=1
```

## Troubleshooting

### Module Not Found

```bash
# List available modules
./main.sh list

# Check module directory
ls -la modules/

# Ensure proper naming
# Modules must be named: flux_*_module.sh
```

### Permission Issues

```bash
# Fix permissions
chmod +x main.sh
chmod +x modules/*.sh

# For system-wide installation
sudo chown -R root:root /opt/flux
sudo chmod -R 755 /opt/flux
```

### Helper Library Issues

Ensure `flux_helpers.sh` is in the same directory as the modules:

```bash
# Each module sources helpers like this:
source "$SCRIPT_DIR/flux_helpers.sh"

# If using custom locations, symlink the helpers:
ln -s /opt/flux/flux_helpers.sh /opt/flux/modules/
```

## Best Practices

1. **Test First**: Always test in a non-production environment
2. **Use Workflows**: Leverage pre-defined workflows for consistency
3. **Backup**: Create backups before major operations
4. **Log Review**: Check logs at `/var/log/flux-setup.log`
5. **Module Updates**: Update individual modules without affecting others

## Getting Help

```bash
# Framework help
./main.sh help

# Module-specific help
./main.sh load network --help
./main.sh load user --help
./main.sh load ssh --help

# List all modules
./main.sh list

# Check version
./main.sh version
```

## Future Compatibility

The modular architecture allows for:

- Easy addition of new modules
- Module versioning
- Plugin support
- API compatibility

Stay updated with the latest changes by checking the repository regularly.
