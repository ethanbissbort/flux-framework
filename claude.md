# Flux System Administration Framework - Project Context

## Project Overview

Flux is a modular, enterprise-grade Linux system configuration and hardening framework written in Bash. It automates and standardizes server setup, security hardening, and maintenance tasks across multiple Linux distributions (Ubuntu, Debian, CentOS, RHEL).

**Repository**: https://github.com/ethanbissbort/flux-framework

## Architecture

### Core Components

- **main.sh**: Core orchestrator that loads modules, manages workflows, and handles command routing
- **flux-helpers.sh**: Shared helper functions library (logging, error handling, validation)
- **modules/**: Independent, self-contained functional modules
- **config/**: Configuration templates (network configs, ZSH themes)
- **certs/**: SSL/TLS certificate storage
- **docs/**: User documentation and guides

### Module Structure

Each module follows this pattern:
```bash
#!/bin/bash
# flux-MODULE-module.sh - Description
# Version: X.Y.Z

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/flux-helpers.sh" || exit 1

# Set up error handling
setup_error_handling

# Module implementation...
```

### Available Modules

1. **flux-network-module.sh** - Network configuration (static IPs, VLANs, diagnostics)
2. **flux-hostname-module.sh** - Hostname and FQDN management
3. **flux-user-module.sh** - User/group management with SSH keys
4. **flux-ssh-module.sh** - SSH hardening and fail2ban configuration
5. **flux-firewall-module.sh** - Unified firewall (UFW/firewalld)
6. **flux-update-module.sh** - System updates and package management
7. **flux-certs-module.sh** - Certificate installation from git repositories
8. **flux-sysctl-module.sh** - Kernel parameter hardening
9. **flux-zsh-module.sh** - ZSH and Oh-My-Zsh installation
10. **flux-motd-module.sh** - Custom MOTD with ASCII art
11. **flux-netdata-module.sh** - NetData monitoring setup

## Key Technologies

- **Language**: Bash 4+
- **Target**: Linux servers (Ubuntu, Debian, CentOS, RHEL)
- **Dependencies**: Standard Linux utilities, git
- **Security**: UFW/firewalld, fail2ban, sysctl hardening
- **Monitoring**: NetData integration

## Common Workflows

### Predefined Workflows

```bash
# Essential setup (updates, certs, sysctl, SSH hardening)
./main.sh workflow essential

# Complete system setup (all modules)
./main.sh workflow complete

# Security hardening only
./main.sh workflow security

# Development environment
./main.sh workflow development
```

### Module Usage Pattern

```bash
# Load and execute a module
./main.sh load MODULE_NAME [OPTIONS]

# Examples
./main.sh load network -l                    # List interfaces
./main.sh load hostname -i                   # Interactive hostname setup
./main.sh load user --menu                   # User management menu
./main.sh load ssh -w                        # SSH hardening wizard
./main.sh load firewall -p web-server        # Apply firewall preset
```

## Development Guidelines

### Code Style

- **Error Handling**: Always use `setup_error_handling` from helpers
- **Logging**: Use `log_info`, `log_warn`, `log_error`, `log_debug` functions
- **Validation**: Use helper functions: `check_root`, `check_internet`, `validate_ip`, etc.
- **Interactivity**: Support both interactive (`-i`, `--menu`, `-w`) and scriptable modes
- **Idempotence**: Operations should be safe to run multiple times

### Helper Functions Reference

From `flux-helpers.sh`:
- **Logging**: `log_info`, `log_warn`, `log_error`, `log_debug`, `log_success`
- **Validation**: `validate_ip`, `validate_hostname`, `validate_port`, `validate_email`
- **Checks**: `check_root`, `check_internet`, `check_command`, `detect_os`
- **Utilities**: `create_backup`, `confirm_action`, `show_spinner`
- **Error Handling**: `setup_error_handling`, custom error trap

### Testing Approach

1. **Manual Testing**: Test on clean VMs (Ubuntu, Debian, CentOS)
2. **Permissions**: Most operations require root/sudo
3. **Idempotence**: Run modules multiple times to verify
4. **Logs**: Check `/var/log/flux-setup.log` for errors
5. **Rollback**: Use backup functions before destructive changes

### Configuration Files

Network configuration examples in `config/`:
- `90-fluxlab.yaml` - Static network configuration template
- `01-fluxlab-vlan.yaml` - VLAN configuration template
- `.zshrc` - ZSH configuration template
- `fluxlab.zsh-theme` - Custom ZSH theme

## Important Conventions

### File Naming

- Modules: `flux-NAME-module.sh` (must be executable)
- Config templates: Use descriptive names with appropriate extensions
- Backups: Modules create `.bak` files before modifications

### Logging

- **Location**: `/var/log/flux-setup.log` (default)
- **Format**: Timestamped entries with severity levels
- **Levels**: DEBUG, INFO, WARN, ERROR, SUCCESS

### Security Considerations

1. **Root Privileges**: Most modules require root access
2. **SSH Hardening**: Changes SSH port, disables root login, enforces key auth
3. **Firewall**: Default deny policy with explicit allows
4. **Certificate Validation**: Validates cert chains before installation
5. **Input Validation**: All user inputs are validated before use

## Common Tasks for Claude

### Adding a New Module

1. Create `modules/flux-NAME-module.sh` following the module structure
2. Source `flux-helpers.sh` and call `setup_error_handling`
3. Implement module logic with proper logging
4. Add command-line argument parsing
5. Update `main.sh` to recognize the new module
6. Document in README.md

### Debugging Issues

1. Check `/var/log/flux-setup.log` for error messages
2. Verify script has execute permissions: `chmod +x`
3. Ensure running with sudo for system operations
4. Test helper function sourcing path resolution
5. Validate module compatibility with OS distribution

### Extending Functionality

1. Add new functions to `flux-helpers.sh` if reusable
2. Follow existing error handling patterns
3. Support both interactive and non-interactive modes
4. Add appropriate validation for all inputs
5. Create backups before destructive operations

## Environment Variables

```bash
FLUX_MODULES_DIR    # Module directory (default: ./modules)
FLUX_CONFIG_DIR     # Configuration directory (default: ~/.config/flux)
LOGFILE             # Log file location (default: /var/log/flux-setup.log)
LOG_LEVEL           # Log level: 0=debug, 1=info, 2=warn, 3=error
```

## Quick Reference

### Repository Structure
```
flux-framework/
├── main.sh                          # Core orchestrator
├── flux-helpers.sh                  # Shared utilities
├── modules/                         # Functional modules
│   ├── flux-network-module.sh      # Network management
│   ├── flux-user-module.sh         # User management
│   ├── flux-ssh-module.sh          # SSH hardening
│   └── ...                         # Other modules
├── config/                          # Templates
├── certs/                          # Certificates
├── docs/                           # Documentation
├── README.md                       # Main documentation
└── LICENSE                         # MIT License
```

### Key Commands
```bash
./main.sh help              # Show help
./main.sh list              # List modules
./main.sh status            # System status
./main.sh workflow NAME     # Run workflow
./main.sh load MODULE [OPT] # Load module
```

## Notes for AI Assistance

- This is production system administration code - changes affect live systems
- Always suggest testing in non-production environments first
- Prioritize security and idempotence in all modifications
- Respect existing code patterns and conventions
- Use helper functions rather than reinventing utilities
- Document all new features and changes
- Consider multi-distribution compatibility (apt vs yum/dnf)

## Known Patterns

1. **Distribution Detection**: Use `detect_os` helper to support multiple distros
2. **Interactive vs Scripted**: Support both `-i` (interactive) and direct flags
3. **Wizards**: Complex modules offer `-w` wizard mode for guided setup
4. **Backups**: Create backups with `create_backup` before modifications
5. **Confirmation**: Use `confirm_action` for destructive operations
6. **Menu Systems**: User module uses dialog-based menus for complex operations
