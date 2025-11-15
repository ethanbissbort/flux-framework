# 🚀 Flux Framework - Quick Start Guide

Get your Linux server production-ready in under 10 minutes!

---

## 📋 Table of Contents

- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [First Run](#-first-run)
- [Essential Workflow](#-essential-workflow)
- [What's Next](#-whats-next)
- [Common Tasks](#-common-tasks)
- [Getting Help](#-getting-help)

---

## ✅ Prerequisites

Before you begin, ensure you have:

| Requirement | Details |
|-------------|---------|
| **Operating System** | Ubuntu 18.04+, Debian 10+, CentOS 7+, RHEL 7+ |
| **Access** | Root or sudo privileges |
| **Tools** | git, bash 4.0+ |
| **Network** | Internet connection |
| **Disk Space** | At least 1GB free |

### Quick Check

```bash
# Check your OS
cat /etc/os-release

# Check bash version (need 4.0+)
bash --version

# Check if you have sudo
sudo -v

# Check internet connection
ping -c 3 8.8.8.8
```

---

## 📦 Installation

### Method 1: One-Line Install (Recommended)

```bash
git clone https://github.com/ethanbissbort/flux-framework.git && \
cd flux-framework && \
chmod +x *.sh modules/*.sh && \
sudo ./main.sh workflow essential
```

This will:
1. Clone the repository
2. Make all scripts executable
3. Run the essential setup workflow

### Method 2: Step-by-Step Install

```bash
# Step 1: Clone the repository
git clone https://github.com/ethanbissbort/flux-framework.git

# Step 2: Enter the directory
cd flux-framework

# Step 3: Make scripts executable
chmod +x main.sh flux-helpers.sh
chmod +x modules/*.sh

# Step 4: Verify installation
./main.sh version
```

Expected output:
```
Flux System Administration Framework
Version: 3.0.0
Release: 2025.05
...
```

---

## 🎯 First Run

### Understanding the Interface

```bash
# Show all available commands
./main.sh help

# List all modules
./main.sh list

# List all workflows
./main.sh workflows

# Check your system status
./main.sh status
```

### Test a Simple Module

```bash
# Run the sysctl module to show current settings
./main.sh load sysctl --show
```

This is a safe, read-only operation that shows you what Flux can do.

---

## 🔷 Essential Workflow

The **Essential Workflow** is perfect for getting started. It performs the minimum required setup for a secure server.

### What It Does

1. **System Update** (~3 min)
   - Updates all packages
   - Installs essential tools
   - Cleans up package cache

2. **Certificate Installation** (~1 min)
   - Installs trusted CA certificates
   - Updates system trust store

3. **Kernel Hardening** (~1 min)
   - Applies secure sysctl parameters
   - Enables SYN flood protection
   - Configures BBR congestion control

4. **SSH Hardening** (~2 min)
   - Hardens SSH configuration
   - Disables weak ciphers
   - Configures secure settings

### Running the Workflow

#### Interactive Mode (Recommended for First Time)

```bash
sudo ./main.sh workflow essential
```

You'll be prompted before each step:
```
Execute update module? [Y/n]:
Execute certs module? [Y/n]:
Execute sysctl module? [Y/n]:
Execute ssh module? [Y/n]:
```

#### Non-Interactive Mode

```bash
sudo ./main.sh workflow essential -y
```

All modules run automatically without prompts.

### What to Expect

```
[INFO] Executing workflow: essential
================================================================================
Workflow: essential
================================================================================

This workflow will execute 4 modules:
  - update
  - certs
  - sysctl
  - ssh

Proceed with workflow? [Y/n]: y

--------------------------------------------------------------------------------
[Step 1/4] Module: update
--------------------------------------------------------------------------------
[INFO] Loading module: update
...
✓ Module update completed successfully

--------------------------------------------------------------------------------
[Step 2/4] Module: certs
--------------------------------------------------------------------------------
[INFO] Loading module: certs
...
✓ Module certs completed successfully

... (continues for all modules)

================================================================================
Workflow Summary
================================================================================
Workflow: essential
Duration: 287s

✓ Completed: 4
```

---

## 🎉 What's Next?

### Option 1: Run the Security Workflow

Add firewall protection:

```bash
sudo ./main.sh workflow security
```

This includes everything from **essential** plus:
- Firewall configuration
- Fail2ban setup

### Option 2: Run Individual Modules

Configure specific components:

```bash
# Set hostname
sudo ./main.sh load hostname -n myserver

# Create an admin user
sudo ./main.sh load user -a

# Configure network
sudo ./main.sh load network -c
```

### Option 3: Check System Status

```bash
./main.sh status
```

You'll see:
- System information
- Resource usage
- Network configuration
- Service status
- Available updates

---

## 🔧 Common Tasks

### Change SSH Port

```bash
sudo ./main.sh load ssh -p 2222
```

### Create a New User

```bash
sudo ./main.sh load user -c alice \
  --fullname "Alice Johnson" \
  --groups "sudo,docker"
```

### Add SSH Key for User

```bash
# From local file
sudo ./main.sh load user -k alice ~/.ssh/id_rsa.pub

# From GitHub
sudo ./main.sh load user -k alice https://github.com/alice.keys
```

### Configure Firewall

```bash
# Interactive wizard
sudo ./main.sh load firewall -w

# Or allow specific port
sudo ./main.sh load firewall -a 8080/tcp
```

### Install Monitoring

```bash
sudo ./main.sh load netdata
```

Access NetData at: `http://your-server-ip:19999`

### Setup ZSH

```bash
# Basic installation
sudo ./main.sh load zsh

# With Powerlevel10k theme
sudo ./main.sh load zsh -p
```

---

## 📚 Getting Help

### Module Help

Every module has built-in help:

```bash
./main.sh load MODULE --help

# Examples
./main.sh load ssh --help
./main.sh load network --help
./main.sh load sysctl --help
```

### View Logs

```bash
# View recent logs
tail -f /var/log/flux-setup.log

# Search for errors
grep ERROR /var/log/flux-setup.log

# View last 100 lines
tail -100 /var/log/flux-setup.log
```

### Check Configuration

```bash
# View current config
cat ~/.config/flux/flux.conf

# Check sysctl settings
./main.sh load sysctl --show

# Verify sysctl is applied
./main.sh load sysctl --verify
```

### Common Issues

#### Module Not Found

```bash
# List available modules
./main.sh list

# Verify module exists
ls -la modules/flux-*-module.sh
```

#### Permission Denied

```bash
# Make sure scripts are executable
chmod +x *.sh modules/*.sh

# Use sudo for system operations
sudo ./main.sh workflow essential
```

#### Internet Connection

```bash
# Test connectivity
ping -c 4 8.8.8.8

# Check DNS
nslookup google.com
```

---

## 🎓 Next Steps

1. **Read the Module Reference**
   - Learn about all available modules
   - Understand module options
   - See advanced use cases

2. **Review Security Guide**
   - Understand security features
   - Learn best practices
   - Configure advanced security

3. **Explore Configuration Options**
   - Customize Flux behavior
   - Set default values
   - Configure workflows

4. **Check Troubleshooting Guide**
   - Common problems and solutions
   - Debug techniques
   - Getting support

---

## 📖 Additional Resources

| Resource | Description |
|----------|-------------|
| [Module Reference](module-reference.md) | Detailed module documentation |
| [Security Guide](security-guide.md) | Security best practices |
| [Configuration Guide](configuration-guide.md) | All configuration options |
| [Troubleshooting](troubleshooting.md) | Solutions to common issues |
| [Contributing](contributing.md) | How to contribute |

---

## 💡 Pro Tips

1. **Always review logs**: Check `/var/log/flux-setup.log` after operations
2. **Test in a VM first**: Try Flux in a test environment before production
3. **Use workflows**: They're designed for common scenarios
4. **Read module help**: Every module has `--help`
5. **Backup before changes**: Flux creates backups, but extra copies don't hurt
6. **Keep Flux updated**: Run `git pull` periodically

---

## ❓ Frequently Asked Questions

### Can I run Flux multiple times?

✅ Yes! Flux is idempotent. Running it multiple times is safe.

### Will Flux break my existing setup?

✅ Flux creates backups before making changes. You can always revert.

### Do I need to reboot after running Flux?

⚠️ Usually not immediately, but Flux will tell you if a reboot is needed.

### Can I use Flux in automation/scripts?

✅ Yes! Use non-interactive mode: `./main.sh workflow NAME -y`

### Does Flux work on other Linux distributions?

✅ Yes! Tested on Ubuntu, Debian, CentOS, RHEL, Rocky, and AlmaLinux.

---

<div align="center">

**🎉 Congratulations! You're now ready to use Flux Framework! 🎉**

[← Back to README](../README.md) | [Module Reference →](module-reference.md)

</div>
