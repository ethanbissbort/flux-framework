# 🔧 Flux Framework - Troubleshooting Guide

Solutions to common issues and problems when using Flux Framework.

---

## 📋 Table of Contents

- [Quick Diagnostics](#-quick-diagnostics)
- [Installation Issues](#-installation-issues)
- [Module Errors](#-module-errors)
- [Network Problems](#-network-problems)
- [Permission Issues](#-permission-issues)
- [SSH Problems](#-ssh-problems)
- [Firewall Issues](#-firewall-issues)
- [Performance Issues](#-performance-issues)
- [Log Analysis](#-log-analysis)
- [Getting Support](#-getting-support)

---

## 🏥 Quick Diagnostics

### Run System Check

```bash
# Check overall system status
./main.sh status

# Verify Flux installation
./main.sh version

# List available modules
./main.sh list
```

### Check Logs

```bash
# View recent log entries
tail -50 /var/log/flux-setup.log

# Follow logs in real-time
tail -f /var/log/flux-setup.log

# Search for errors
grep -i error /var/log/flux-setup.log

# Search for specific module
grep "Module: ssh" /var/log/flux-setup.log
```

### Verify File Permissions

```bash
# Check main script
ls -la main.sh

# Check all modules
ls -la modules/*.sh

# Fix permissions if needed
chmod +x main.sh flux-helpers.sh modules/*.sh
```

---

## 📦 Installation Issues

### Error: `bash: ./main.sh: Permission denied`

**Problem**: Script is not executable.

**Solution**:
```bash
chmod +x main.sh flux-helpers.sh modules/*.sh
```

### Error: `git: command not found`

**Problem**: Git is not installed.

**Solution**:
```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y git

# CentOS/RHEL
sudo yum install -y git
```

### Error: `flux-helpers.sh not found`

**Problem**: Helper library is missing or in wrong location.

**Solutions**:

1. Verify helpers file exists:
```bash
ls -la flux-helpers.sh
```

2. Re-clone the repository:
```bash
cd ..
rm -rf flux-framework
git clone https://github.com/ethanbissbort/flux-framework.git
cd flux-framework
```

3. Check file structure:
```bash
# Should show both files in same directory
ls -la main.sh flux-helpers.sh
```

### Modules Not Loading

**Problem**: Modules directory missing or empty.

**Solution**:
```bash
# Check modules directory
ls -la modules/

# Should show 11 module files
# If empty or missing, re-clone repository
```

---

## 🧩 Module Errors

### Module Not Found Error

**Error Message**:
```
[ERROR] Module not found: modulename
```

**Solutions**:

1. List available modules:
```bash
./main.sh list
```

2. Check exact module name:
```bash
# Correct
./main.sh load sysctl

# Incorrect
./main.sh load sysctrl
```

3. Verify module file exists:
```bash
ls -la modules/flux-*-module.sh
```

### Module Syntax Errors

**Error Message**:
```
[ERROR] Module has syntax errors: modulename
```

**Solutions**:

1. Check module syntax:
```bash
bash -n modules/flux-modulename-module.sh
```

2. View detailed error:
```bash
bash -x modules/flux-modulename-module.sh
```

3. Restore from backup or re-clone.

### Module Timeout

**Error Message**:
```
[ERROR] Module modulename timed out after 300s
```

**Solutions**:

1. Increase timeout in config:
```bash
# Edit ~/.config/flux/flux.conf
MODULE_TIMEOUT=600  # 10 minutes
```

2. Or set via environment:
```bash
export MODULE_TIMEOUT=600
./main.sh load slowmodule
```

3. Run module directly:
```bash
cd modules
sudo ./flux-modulename-module.sh
```

---

## 🌐 Network Problems

### No Internet Connection

**Error**: Unable to download packages or updates.

**Diagnostics**:
```bash
# Test basic connectivity
ping -c 4 8.8.8.8

# Test DNS resolution
nslookup google.com

# Check default gateway
ip route show default

# Check DNS servers
cat /etc/resolv.conf
```

**Solutions**:

1. Configure DNS servers:
```bash
# Edit /etc/resolv.conf
nameserver 1.1.1.1
nameserver 8.8.8.8
```

2. Restart networking:
```bash
# Ubuntu/Debian with netplan
sudo netplan apply

# NetworkManager
sudo systemctl restart NetworkManager

# Traditional networking
sudo systemctl restart networking
```

### Proxy Issues

**Problem**: Behind a corporate proxy.

**Solution**:
```bash
# Set proxy environment variables
export http_proxy="http://proxy.example.com:8080"
export https_proxy="http://proxy.example.com:8080"
export no_proxy="localhost,127.0.0.1"

# Make permanent in ~/.bashrc
echo 'export http_proxy="http://proxy.example.com:8080"' >> ~/.bashrc
echo 'export https_proxy="http://proxy.example.com:8080"' >> ~/.bashrc
```

### Package Download Failures

**Error**: `Failed to download package` or `404 Not Found`

**Solutions**:

1. Update package lists:
```bash
# Ubuntu/Debian
sudo apt-get update

# CentOS/RHEL
sudo yum clean all
sudo yum update
```

2. Check repository configuration:
```bash
# Ubuntu/Debian
ls -la /etc/apt/sources.list.d/

# CentOS/RHEL
ls -la /etc/yum.repos.d/
```

---

## 🔐 Permission Issues

### Error: `This operation requires root privileges`

**Problem**: Running system operations without sudo.

**Solution**:
```bash
# Use sudo for system operations
sudo ./main.sh workflow essential
sudo ./main.sh load sysctl --apply
```

### Error: `Failed to create directory`

**Problem**: Insufficient permissions for directory creation.

**Solutions**:

1. Run with sudo:
```bash
sudo ./main.sh load module
```

2. Change ownership (if appropriate):
```bash
sudo chown -R $USER:$USER ~/.config/flux
```

3. Check parent directory permissions:
```bash
ls -la /var/log
ls -la ~/.config
```

### Error: `Failed to make module executable`

**Problem**: Cannot chmod module files.

**Solutions**:

1. Use sudo to fix permissions:
```bash
sudo chmod +x modules/*.sh
```

2. Check file ownership:
```bash
ls -la modules/
```

3. Change ownership if needed:
```bash
sudo chown -R $USER:$USER .
chmod +x *.sh modules/*.sh
```

---

## 🔑 SSH Problems

### Locked Out After SSH Hardening

**Problem**: Cannot SSH after running SSH module.

**Prevention**:
```bash
# ALWAYS test SSH config before applying
sudo sshd -t

# Keep existing session open while testing
```

**Solutions**:

1. Console access method:
```bash
# Access via console (VM console, IPMI, etc.)
# Restore SSH config from backup
sudo cp /etc/ssh/sshd_config.backup* /etc/ssh/sshd_config
sudo systemctl restart sshd
```

2. Alternative: Revert sysctl changes:
```bash
# Remove SSH port from sysctl
sudo sed -i '/Port /d' /etc/ssh/sshd_config
sudo systemctl restart sshd
```

3. Recovery via single-user mode:
```bash
# Boot into single-user mode
# Edit /etc/ssh/sshd_config
# Set: PermitRootLogin yes
# Set: PasswordAuthentication yes
# Reboot
```

### SSH Connection Refused

**Diagnostics**:
```bash
# Check if SSH is running
sudo systemctl status sshd

# Check SSH port
sudo netstat -tlnp | grep sshd

# Check firewall rules
sudo ufw status
sudo firewall-cmd --list-all
```

**Solutions**:

1. Start SSH service:
```bash
sudo systemctl start sshd
sudo systemctl enable sshd
```

2. Check correct port:
```bash
# If changed to port 2222
ssh -p 2222 user@host
```

3. Check firewall:
```bash
# UFW
sudo ufw allow 2222/tcp

# firewalld
sudo firewall-cmd --permanent --add-port=2222/tcp
sudo firewall-cmd --reload
```

---

## 🛡️ Firewall Issues

### Locked Out After Firewall Configuration

**Problem**: Cannot access server after enabling firewall.

**Prevention**:
```bash
# ALWAYS allow SSH before enabling firewall
sudo ufw allow 22/tcp  # or your SSH port
sudo ufw enable
```

**Recovery**:

1. Via console access:
```bash
# Disable firewall
sudo ufw disable

# Or allow your IP
sudo ufw allow from YOUR_IP_ADDRESS
```

2. Via recovery mode:
```bash
# Boot to recovery/single-user mode
sudo ufw disable
```

### Rules Not Working

**Diagnostics**:
```bash
# UFW
sudo ufw status verbose
sudo ufw status numbered

# firewalld
sudo firewall-cmd --list-all
sudo firewall-cmd --list-ports
```

**Solutions**:

1. Reload firewall:
```bash
# UFW
sudo ufw reload

# firewalld
sudo firewall-cmd --reload
```

2. Check rule order:
```bash
# UFW - rules are processed in order
sudo ufw status numbered
```

3. Reset and reconfigure:
```bash
# UFW
sudo ufw reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw enable
```

---

## ⚡ Performance Issues

### Slow Module Execution

**Problem**: Modules taking too long to complete.

**Diagnostics**:
```bash
# Check system resources
top
free -h
df -h

# Check network speed
curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
```

**Solutions**:

1. Increase module timeout:
```bash
export MODULE_TIMEOUT=900  # 15 minutes
```

2. Run modules individually:
```bash
# Instead of workflow, run one at a time
sudo ./main.sh load update
sudo ./main.sh load sysctl
```

3. Check for stuck processes:
```bash
ps aux | grep flux
```

### High Memory Usage

**Problem**: System running out of memory.

**Solutions**:

1. Check memory usage:
```bash
free -h
top
```

2. Clear cache:
```bash
# Clear apt cache
sudo apt-get clean

# Clear yum cache
sudo yum clean all
```

3. Add swap space:
```bash
# Create 2GB swap file
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

---

## 📊 Log Analysis

### Understanding Log Levels

```
[DEBUG] - Detailed information for debugging
[INFO]  - General informational messages
[WARN]  - Warning messages (non-critical)
[ERROR] - Error messages (critical)
```

### Common Log Patterns

#### Successful Operation
```
[INFO] Loading module: sysctl
[INFO] Applying sysctl configuration
✓ Module sysctl completed successfully
```

#### Failed Operation
```
[INFO] Loading module: ssh
[ERROR] Failed to backup /etc/ssh/sshd_config
[ERROR] Module ssh failed with exit code: 1
```

### Searching Logs

```bash
# Find all errors
grep -i '\[ERROR\]' /var/log/flux-setup.log

# Find specific module logs
grep 'Module: ssh' /var/log/flux-setup.log

# Find recent errors (last hour)
find /var/log/flux-setup.log -mmin -60 -exec grep ERROR {} \;

# Get context around error
grep -A 5 -B 5 ERROR /var/log/flux-setup.log
```

### Enable Debug Logging

```bash
# Set debug level
export LOG_LEVEL=0

# Or in config
echo "LOG_LEVEL=0" >> ~/.config/flux/flux.conf

# Run module with debug
./main.sh load sysctl --show
```

---

## 🆘 Getting Support

### Before Asking for Help

1. **Check the documentation**:
   - [Quick Start Guide](quick-start.md)
   - [Module Reference](module-reference.md)
   - [Security Guide](security-guide.md)

2. **Search existing issues**:
   - [GitHub Issues](https://github.com/ethanbissbort/flux-framework/issues)

3. **Gather information**:
   ```bash
   # System info
   cat /etc/os-release
   uname -a

   # Flux version
   ./main.sh version

   # Recent logs
   tail -100 /var/log/flux-setup.log
   ```

### Reporting Bugs

When creating an issue, include:

1. **Clear title**:
   - Good: "SSH module fails on Ubuntu 22.04 with custom port"
   - Bad: "Doesn't work"

2. **Steps to reproduce**:
   ```
   1. Run: ./main.sh load ssh -p 2222
   2. Error occurs at step X
   3. See log output below
   ```

3. **Expected vs actual behavior**:
   - Expected: SSH should listen on port 2222
   - Actual: Error message XYZ

4. **Environment**:
   - OS: Ubuntu 22.04
   - Flux version: 3.0.0
   - Bash version: 5.1.16

5. **Relevant logs**:
   ```
   Paste relevant log entries here
   ```

6. **Screenshots** (if applicable)

### Community Support

- **GitHub Issues**: [Report bugs](https://github.com/ethanbissbort/flux-framework/issues/new)
- **GitHub Discussions**: [Ask questions](https://github.com/ethanbissbort/flux-framework/discussions)
- **Documentation**: [Read the docs](../README.md)

---

## 🔍 Advanced Debugging

### Run Module in Debug Mode

```bash
# Enable bash debug mode
bash -x modules/flux-modulename-module.sh

# Or set in script
set -x  # Enable debug
set +x  # Disable debug
```

### Check Module Syntax

```bash
# Syntax check without execution
bash -n modules/flux-modulename-module.sh
```

### Trace Module Execution

```bash
# Detailed trace
bash -xv modules/flux-modulename-module.sh 2>&1 | tee debug.log
```

### Simulate Module Run

```bash
# Dry run (if module supports it)
./main.sh load module --dry-run

# Or review what it would do
cat modules/flux-module-module.sh
```

---

## ✅ Prevention Best Practices

1. **Always backup**: Flux creates backups, but create your own too
2. **Test in VM first**: Never test on production directly
3. **Keep console access**: Don't rely only on SSH
4. **Read logs**: Review logs after each operation
5. **One change at a time**: Don't run multiple modules simultaneously
6. **Know your baseline**: Run `./main.sh status` before changes
7. **Document changes**: Keep notes of what you've modified
8. **Stay updated**: Run `git pull` to get latest fixes

---

<div align="center">

**Can't find your issue? [Create a new issue](https://github.com/ethanbissbort/flux-framework/issues/new)** 📝

[← Back to README](../README.md) | [Quick Start →](quick-start.md)

</div>
