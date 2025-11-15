# 🚀 Flux System Administration Framework

[![Version](https://img.shields.io/badge/version-3.0.0-blue.svg)](https://github.com/ethanbissbort/flux-framework)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4%2B-orange.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-linux-lightgrey.svg)](https://www.linux.org/)

> A modular, enterprise-grade Linux system configuration and hardening framework built for DevOps engineers and system administrators.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Key Features](#-key-features)
- [Quick Start](#-quick-start)
- [Installation](#-installation)
- [Architecture](#-architecture)
- [Usage](#-usage)
- [Workflows](#-workflows)
- [Modules](#-modules)
- [Configuration](#-configuration)
- [Documentation](#-documentation)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🎯 Overview

**Flux Framework** is a comprehensive system administration toolkit designed to automate and standardize Linux server configuration. Built with modularity and security at its core, it provides a consistent, reliable interface for system setup, hardening, and maintenance across multiple Linux distributions.

### Why Flux?

- ⚡ **Fast Setup** - Get a production-ready server in minutes
- 🔒 **Security Hardened** - Industry best practices baked in
- 🧩 **Modular Design** - Use only what you need
- 🔄 **Idempotent** - Safe to run multiple times
- 📊 **Well Tested** - Battle-tested on Ubuntu, Debian, CentOS, RHEL
- 📝 **Self-Documenting** - Comprehensive logs and help text

---

## ✨ Key Features

### 🔧 Modular Architecture
Each function is a separate, independent module that can be used standalone or as part of a workflow.

### 🔒 Security First
- SSH hardening with modern ciphers and key algorithms
- Automatic firewall configuration (UFW/firewalld)
- Kernel parameter hardening via sysctl
- Fail2ban integration for intrusion prevention
- Certificate management with validation

### 🚀 Workflow Automation
Pre-defined workflows for common scenarios:
- **Essential** - Basic server setup
- **Security** - Comprehensive hardening
- **Complete** - Full system configuration
- **Development** - Dev environment setup
- **Monitoring** - Observability stack

### 📝 Comprehensive Logging
- Detailed operation logging to `/var/log/flux-setup.log`
- Color-coded console output
- Configurable log levels (debug, info, warn, error)
- Error tracking with line numbers and stack traces

### 🎯 Interactive & Scriptable
- Interactive wizards for guided setup
- Non-interactive mode for automation
- Help text for every module and option
- Argument validation and helpful error messages

### 🌐 Multi-Distribution Support
Tested and working on:
- ✅ Ubuntu (18.04, 20.04, 22.04, 24.04)
- ✅ Debian (10, 11, 12)
- ✅ CentOS (7, 8, Stream)
- ✅ RHEL (7, 8, 9)
- ✅ Rocky Linux
- ✅ AlmaLinux

---

## 🚀 Quick Start

### One-Line Install

```bash
git clone https://github.com/ethanbissbort/flux-framework.git && cd flux-framework && chmod +x *.sh modules/*.sh && sudo ./main.sh workflow essential
```

### Step-by-Step

```bash
# 1. Clone the repository
git clone https://github.com/ethanbissbort/flux-framework.git
cd flux-framework

# 2. Make scripts executable
chmod +x *.sh modules/*.sh

# 3. View available commands
./main.sh help

# 4. Run essential setup (interactive)
sudo ./main.sh workflow essential

# 5. Or run complete setup (all modules)
sudo ./main.sh workflow complete
```

### 🎬 What Happens During Essential Workflow?

1. **System Update** - Updates packages and installs essentials
2. **Certificate Installation** - Installs trusted certificates
3. **Kernel Hardening** - Applies secure sysctl parameters
4. **SSH Hardening** - Secures SSH with modern crypto

⏱️ **Estimated time**: 5-10 minutes (depending on system and internet speed)

---

## 📦 Installation

### Prerequisites

- **OS**: Linux (Ubuntu, Debian, CentOS, RHEL, or derivatives)
- **Privileges**: Root or sudo access
- **Tools**: git, bash 4+
- **Network**: Internet connection (for package downloads)

### Standard Installation

```bash
# Clone repository
git clone https://github.com/ethanbissbort/flux-framework.git

# Navigate to directory
cd flux-framework

# Make scripts executable
chmod +x main.sh flux-helpers.sh modules/*.sh

# Verify installation
./main.sh version
```

### Portable Installation

Want to keep Flux in `/opt` or another location?

```bash
# Move to preferred location
sudo mv flux-framework /opt/flux

# Create symlink for easy access
sudo ln -s /opt/flux/main.sh /usr/local/bin/flux

# Use from anywhere
flux help
```

---

## 🏗️ Architecture

### Directory Structure

```
flux-framework/
│
├── 📄 main.sh                      # Core orchestrator
├── 📄 flux-helpers.sh              # Shared helper library
│
├── 📁 modules/                     # Functional modules
│   ├── flux-certs-module.sh       # 🔐 Certificate management
│   ├── flux-firewall-module.sh    # 🛡️  Firewall configuration
│   ├── flux-hostname-module.sh    # 🏷️  Hostname management
│   ├── flux-motd-module.sh        # 💬 MOTD customization
│   ├── flux-netdata-module.sh     # 📊 Monitoring setup
│   ├── flux-network-module.sh     # 🌐 Network configuration
│   ├── flux-ssh-module.sh         # 🔑 SSH hardening
│   ├── flux-sysctl-module.sh      # ⚙️  Kernel parameters
│   ├── flux-update-module.sh      # 📦 System updates
│   ├── flux-user-module.sh        # 👤 User management
│   └── flux-zsh-module.sh         # 🐚 ZSH installation
│
├── 📁 config/                      # Configuration templates
│   ├── .zshrc                     # ZSH configuration
│   ├── fluxlab.zsh-theme          # Custom theme
│   ├── 90-fluxlab.yaml            # Netplan template
│   └── 01-fluxlab-vlan.yaml       # VLAN template
│
├── 📁 certs/                       # Certificate storage
├── 📁 docs/                        # Documentation
│   ├── quick-start.md             # Getting started guide
│   ├── module-reference.md        # Detailed module docs
│   ├── configuration-guide.md     # Configuration options
│   ├── security-guide.md          # Security best practices
│   └── troubleshooting.md         # Common issues & solutions
│
└── 📄 LICENSE                      # MIT License
```

### Component Overview

| Component | Purpose | Type |
|-----------|---------|------|
| `main.sh` | Framework orchestrator | Core |
| `flux-helpers.sh` | Reusable functions | Library |
| `modules/*.sh` | Individual features | Modules |
| `config/*` | Configuration templates | Templates |
| `docs/*` | Documentation | Docs |

---

## 💻 Usage

### Framework Commands

```bash
# Display help
./main.sh help

# Show version and modules
./main.sh version

# List all available modules
./main.sh list

# List all workflows
./main.sh workflows

# Check system status
./main.sh status

# Set configuration value
./main.sh config KEY VALUE
```

### Module Operations

```bash
# General syntax
./main.sh load MODULE [OPTIONS]

# Get module help
./main.sh load MODULE --help

# Examples
./main.sh load network -l              # List interfaces
./main.sh load hostname -i             # Interactive hostname setup
./main.sh load user --menu             # User management menu
./main.sh load ssh -w                  # SSH hardening wizard
./main.sh load sysctl --verify         # Verify sysctl settings
```

### Environment Variables

```bash
# Module directory (default: ./modules)
export FLUX_MODULES_DIR=/opt/flux/modules

# Configuration directory (default: ~/.config/flux)
export FLUX_CONFIG_DIR=/etc/flux

# Log file (default: /var/log/flux-setup.log)
export LOGFILE=/var/log/flux.log

# Log level (0=debug, 1=info, 2=warn, 3=error)
export LOG_LEVEL=1
```

---

## 🔄 Workflows

Workflows are pre-defined sequences of modules for common scenarios.

### Available Workflows

| Workflow | Modules | Purpose | Time |
|----------|---------|---------|------|
| **essential** | update, certs, sysctl, ssh | Basic server setup | ~5 min |
| **security** | update, certs, sysctl, ssh, firewall | Security hardening | ~10 min |
| **complete** | All modules | Full system configuration | ~20 min |
| **development** | update, zsh | Dev environment | ~8 min |
| **monitoring** | update, netdata | Monitoring stack | ~7 min |

### Running Workflows

```bash
# Interactive mode (prompts for each step)
sudo ./main.sh workflow essential

# Non-interactive mode (auto-execute all)
sudo ./main.sh workflow essential -y

# Check what's in a workflow
./main.sh workflows
```

### Workflow Details

#### 🔷 Essential Workflow
Perfect for new servers that need basic hardening.

```bash
sudo ./main.sh workflow essential
```

**Includes:**
- ✅ System updates and essential packages
- ✅ Trusted certificate installation
- ✅ Kernel security hardening
- ✅ SSH server hardening

#### 🔶 Security Workflow
Comprehensive security hardening for production servers.

```bash
sudo ./main.sh workflow security
```

**Includes:**
- ✅ Everything in Essential
- ✅ Firewall configuration (UFW/firewalld)
- ✅ Fail2ban setup
- ✅ Security auditing

#### 🔵 Complete Workflow
Full server configuration with all modules.

```bash
sudo ./main.sh workflow complete
```

**Includes:**
- ✅ Everything in Security
- ✅ Hostname and network configuration
- ✅ User and group management
- ✅ ZSH and Oh-My-Zsh
- ✅ Custom MOTD
- ✅ NetData monitoring

---

## 🧩 Modules

### 📦 Update Module
System updates and package installation.

```bash
# Full system update
./main.sh load update -f

# Security updates only
./main.sh load update -s

# With development packages
./main.sh load update -f -d
```

### 🌐 Network Module
Network configuration and management.

```bash
# List interfaces
./main.sh load network -l

# Configure static IP
./main.sh load network --static eth0 192.168.1.100

# Add VLAN
./main.sh load network --add-vlan eth0 100

# Network diagnostics
./main.sh load network -d
```

### 🏷️ Hostname Module
System hostname and FQDN configuration.

```bash
# Show current hostname
./main.sh load hostname -s

# Set hostname
./main.sh load hostname -n webserver

# Set FQDN
./main.sh load hostname -f webserver.example.com

# Interactive mode
./main.sh load hostname -i
```

### 👤 User Module
User and group management with SSH key support.

```bash
# Interactive menu
./main.sh load user --menu

# Create admin user
./main.sh load user -a

# Create user with details
./main.sh load user -c john \
  --fullname "John Doe" \
  --groups "developers,docker"

# Add SSH key
./main.sh load user -k john ~/.ssh/id_rsa.pub

# Import GitHub keys
./main.sh load user -k john https://github.com/johndoe.keys
```

### 🔑 SSH Module
SSH server hardening and security.

```bash
# Interactive hardening wizard
./main.sh load ssh -w

# Apply recommended hardening
./main.sh load ssh --harden

# Change SSH port
./main.sh load ssh -p 2222

# Security audit
./main.sh load ssh -a

# Setup fail2ban
./main.sh load ssh --fail2ban
```

### 🛡️ Firewall Module
Unified firewall management (UFW/firewalld).

```bash
# Interactive wizard
./main.sh load firewall -w

# Apply preset
./main.sh load firewall -p web-server

# Allow port
./main.sh load firewall -a 8080/tcp

# List rules
./main.sh load firewall -l

# Backup rules
./main.sh load firewall --backup
```

### 🔐 Certificate Module
SSL/TLS certificate installation.

```bash
# Install from default repo
./main.sh load certs

# Custom repository
./main.sh load certs -c https://github.com/myorg/certs

# List certificates
./main.sh load certs -l

# Verify certificates
./main.sh load certs -v
```

### ⚙️ Sysctl Module
Kernel parameter hardening.

```bash
# Apply hardening
./main.sh load sysctl --apply

# Force overwrite
./main.sh load sysctl --apply --force

# Verify settings
./main.sh load sysctl --verify

# Show configuration
./main.sh load sysctl --show

# Remove hardening
./main.sh load sysctl --remove
```

### 🐚 ZSH Module
ZSH and Oh-My-Zsh installation.

```bash
# Install with defaults
./main.sh load zsh

# Install with Powerlevel10k
./main.sh load zsh -p

# Update plugins
./main.sh load zsh -u
```

### 💬 MOTD Module
Custom login message (Message of the Day).

```bash
# Interactive setup
./main.sh load motd -s

# Specific ASCII art
./main.sh load motd -a flux-large -c blue

# Preview MOTD
./main.sh load motd -p
```

### 📊 NetData Module
Real-time monitoring system.

```bash
# Basic installation
./main.sh load netdata

# With cloud integration
./main.sh load netdata -c YOUR-CLAIM-TOKEN

# With SSL and external access
./main.sh load netdata -s -e --allowed-ips "10.0.0.0/8"
```

---

## ⚙️ Configuration

### Configuration File

Create `~/.config/flux/flux.conf`:

```bash
# Flux Framework Configuration

# Logging
LOG_LEVEL=1                    # 0=debug, 1=info, 2=warn, 3=error
LOGFILE="/var/log/flux-setup.log"

# Modules
AUTO_UPDATE_MODULES=false
MODULE_TIMEOUT=300             # Timeout in seconds

# Network Defaults
DEFAULT_DNS_PRIMARY="1.1.1.1"
DEFAULT_DNS_SECONDARY="8.8.8.8"

# SSH Defaults
DEFAULT_SSH_PORT="22"

# Security
AUTO_SECURITY_UPDATES=true
```

### Module Timeout

Set a timeout for long-running modules:

```bash
# In flux.conf
MODULE_TIMEOUT=600             # 10 minutes

# Or via environment variable
export MODULE_TIMEOUT=600
```

---

## 📚 Documentation

Comprehensive documentation is available in the `docs/` directory:

| Document | Description |
|----------|-------------|
| [Quick Start Guide](docs/quick-start.md) | Get up and running in minutes |
| [Module Reference](docs/module-reference.md) | Detailed module documentation |
| [Configuration Guide](docs/configuration-guide.md) | All configuration options |
| [Security Guide](docs/security-guide.md) | Security best practices |
| [Troubleshooting](docs/troubleshooting.md) | Common issues and solutions |
| [Contributing](docs/contributing.md) | How to contribute |
| [Migration Guide](docs/flux-migration-guide.md) | Upgrading from v2.x |

---

## 🔒 Security Features

### SSH Hardening
- ✅ Modern ciphers and key algorithms
- ✅ Disable password authentication
- ✅ Disable root login
- ✅ Custom SSH port
- ✅ Fail2ban integration
- ✅ Key-only authentication

### Firewall Management
- ✅ Default deny policy
- ✅ Service-based rules
- ✅ Port whitelisting
- ✅ Rate limiting
- ✅ Automatic backup

### Kernel Hardening
- ✅ SYN flood protection
- ✅ IP spoofing prevention
- ✅ ICMP flood protection
- ✅ Reverse path filtering
- ✅ BBR congestion control
- ✅ Address space randomization

### Certificate Management
- ✅ Certificate validation
- ✅ Chain verification
- ✅ Automatic installation
- ✅ System-wide trust

---

## 🛠️ Troubleshooting

### Module Not Found

```bash
# List available modules
./main.sh list

# Check module directory
ls -la modules/
```

### Permission Denied

```bash
# Make scripts executable
chmod +x main.sh modules/*.sh

# Use sudo for system operations
sudo ./main.sh workflow essential
```

### Helper Library Missing

```bash
# Verify helpers file exists
ls -la flux-helpers.sh

# Check logs for details
cat /var/log/flux-setup.log
```

### Internet Connection Issues

```bash
# Test connectivity
ping -c 4 8.8.8.8

# Check DNS resolution
nslookup google.com

# Review proxy settings if behind firewall
echo $http_proxy
```

For more detailed troubleshooting, see the [Troubleshooting Guide](docs/troubleshooting.md).

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Reporting Issues

1. Check [existing issues](https://github.com/ethanbissbort/flux-framework/issues)
2. Create a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs actual behavior
   - System information (OS, version)
   - Relevant logs

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Follow the module structure pattern
4. Add tests if applicable
5. Update documentation
6. Commit changes (`git commit -m 'Add amazing feature'`)
7. Push to branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Development Guidelines

- **Code Style**: Follow existing bash conventions
- **Error Handling**: Use helper functions
- **Testing**: Test on multiple distributions
- **Documentation**: Update docs for new features
- **Logging**: Use appropriate log levels

See [Contributing Guide](docs/contributing.md) for details.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### What This Means

✅ Commercial use
✅ Modification
✅ Distribution
✅ Private use

❌ Liability
❌ Warranty

---

## 🙏 Acknowledgments

- Built with ❤️ and bash for Linux system administration
- Inspired by DevOps best practices and security guidelines
- Thanks to all contributors and users
- Special thanks to the open-source community

---

## 🔗 Links

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/ethanbissbort/flux-framework/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ethanbissbort/flux-framework/discussions)
- **Releases**: [GitHub Releases](https://github.com/ethanbissbort/flux-framework/releases)

---

## 📊 Project Status

- **Version**: 3.0.0
- **Status**: Active Development
- **Last Updated**: 2025-11-15
- **Tested On**: Ubuntu 22.04, Debian 12, CentOS Stream 9
- **Modules**: 11
- **Total Lines**: ~10,000+

---

## 🎯 Roadmap

- [ ] Ansible playbook integration
- [ ] Docker container support
- [ ] Kubernetes cluster setup
- [ ] Web UI for configuration
- [ ] Automated testing suite
- [ ] Module marketplace
- [ ] Multi-language support

---

<div align="center">

**⭐ Star this repo if you find it useful! ⭐**

Made with 🔥 by [Ethan Bissbort](https://github.com/ethanbissbort)

[Report Bug](https://github.com/ethanbissbort/flux-framework/issues) ·
[Request Feature](https://github.com/ethanbissbort/flux-framework/issues) ·
[Documentation](docs/)

</div>
