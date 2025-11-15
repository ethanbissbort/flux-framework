# 🔒 Flux Framework - Security Guide

Best practices and security features for hardening your Linux servers.

---

## 📋 Table of Contents

- [Security Philosophy](#-security-philosophy)
- [SSH Hardening](#-ssh-hardening)
- [Firewall Configuration](#-firewall-configuration)
- [Kernel Hardening](#-kernel-hardening)
- [Certificate Management](#-certificate-management)
- [User Management](#-user-management)
- [Network Security](#-network-security)
- [Security Monitoring](#-security-monitoring)
- [Best Practices](#-best-practices)
- [Security Checklists](#-security-checklists)

---

## 🎯 Security Philosophy

Flux Framework follows these security principles:

- **Defense in Depth**: Multiple layers of security
- **Least Privilege**: Minimal permissions by default
- **Fail Secure**: Safe defaults when in doubt
- **Auditability**: Comprehensive logging
- **Maintainability**: Easy to understand and update

---

## 🔑 SSH Hardening

### What Flux Does

The SSH module applies industry-standard hardening:

#### ✅ Disabled Features
- Password authentication (key-only)
- Root login
- Empty passwords
- X11 forwarding
- TCP forwarding (optional)
- Weak ciphers and algorithms

#### ✅ Enabled Features
- Public key authentication
- Modern cipher suites
- Strong key exchange algorithms
- Secure MACs
- Protocol 2 only

### Recommended Configuration

```bash
# Run the SSH hardening wizard
sudo ./main.sh load ssh -w
```

This will:
1. Backup current SSH config
2. Ask about configuration options
3. Generate secure sshd_config
4. Test configuration
5. Apply changes

### Custom SSH Port

```bash
# Change to non-standard port
sudo ./main.sh load ssh -p 2222
```

**Benefits**:
- Reduces automated attacks
- Cleaner logs
- Better security through obscurity (not sole defense)

**Remember**: Update firewall rules!

```bash
# UFW
sudo ufw allow 2222/tcp
sudo ufw delete allow 22/tcp

# firewalld
sudo firewall-cmd --permanent --add-port=2222/tcp
sudo firewall-cmd --permanent --remove-service=ssh
sudo firewall-cmd --reload
```

### SSH Key Authentication

```bash
# Generate strong SSH key pair (on your local machine)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Or RSA 4096-bit
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Copy to server
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@server

# Test key authentication
ssh -i ~/.ssh/id_ed25519 user@server
```

### Fail2ban Integration

```bash
# Setup fail2ban for SSH protection
sudo ./main.sh load ssh --fail2ban
```

**Configuration**:
- Max retries: 3
- Ban time: 600 seconds (10 minutes)
- Find time: 600 seconds
- Action: iptables ban

### SSH Security Audit

```bash
# Run security audit
sudo ./main.sh load ssh -a
```

Checks:
- Weak ciphers
- Password authentication
- Root login
- Empty passwords
- Key permissions
- Config syntax

---

## 🛡️ Firewall Configuration

### Firewall Strategy

Flux supports both UFW (Ubuntu/Debian) and firewalld (CentOS/RHEL).

#### Default Policy
```
Incoming: DENY
Outgoing: ALLOW
Forwarding: DENY
```

### Quick Setup

```bash
# Interactive wizard
sudo ./main.sh load firewall -w
```

Steps through:
1. Choose firewall (UFW/firewalld)
2. Select preset or custom rules
3. Configure allowed services
4. Enable firewall

### Presets

```bash
# Web server (80, 443, 22)
sudo ./main.sh load firewall -p web-server

# Database server (3306/5432, 22)
sudo ./main.sh load firewall -p database

# Custom rules
sudo ./main.sh load firewall -a 8080/tcp
sudo ./main.sh load firewall -a 3000-3010/tcp
```

### Advanced Rules

```bash
# Allow from specific IP
sudo ufw allow from 192.168.1.100 to any port 22

# Allow subnet
sudo ufw allow from 192.168.1.0/24

# Limit SSH connections (rate limiting)
sudo ufw limit 22/tcp

# Port forwarding
sudo ufw route allow in on eth0 out on eth1
```

### Firewall Best Practices

1. **Whitelist approach**: Deny all, allow specific
2. **Document rules**: Comment why each rule exists
3. **Regular audits**: Review rules monthly
4. **Remove unused**: Delete old rules promptly
5. **Monitor logs**: Check firewall logs regularly

```bash
# View UFW logs
sudo tail -f /var/log/ufw.log

# View firewalld logs
sudo journalctl -u firewalld -f
```

---

## ⚙️ Kernel Hardening

### Sysctl Parameters

Flux applies security-focused kernel parameters:

```bash
# Apply hardening
sudo ./main.sh load sysctl --apply
```

### Key Security Parameters

#### Network Security
```bash
# Disable IP forwarding (not a router)
net.ipv4.ip_forward = 0

# Enable SYN cookies (SYN flood protection)
net.ipv4.tcp_syncookies = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0

# Ignore source routed packets
net.ipv4.conf.all.accept_source_route = 0

# Enable reverse path filtering
net.ipv4.conf.all.rp_filter = 1

# Log martian packets
net.ipv4.conf.all.log_martians = 1

# Ignore ICMP ping requests (optional)
# net.ipv4.icmp_echo_ignore_all = 1
```

#### Kernel Security
```bash
# Address space randomization
kernel.randomize_va_space = 2

# Restrict kernel pointer access
kernel.kptr_restrict = 2

# Restrict dmesg access
kernel.dmesg_restrict = 1

# Disable kernel core dumps
kernel.core_uses_pid = 1
fs.suid_dumpable = 0
```

#### File System Security
```bash
# Protected hardlinks
fs.protected_hardlinks = 1

# Protected symlinks
fs.protected_symlinks = 1

# Increase file descriptor limit
fs.file-max = 65535
```

### Verifying Applied Settings

```bash
# Verify all settings
sudo ./main.sh load sysctl --verify

# Check specific parameter
sysctl net.ipv4.tcp_syncookies

# View all sysctl parameters
sysctl -a | grep ipv4
```

### Performance vs Security

Some parameters affect performance:

- **BBR Congestion Control**: Better performance, secure
- **SYN Cookies**: Slight overhead, prevents attacks
- **Reverse Path Filtering**: Minimal impact, good security

**Recommendation**: Keep all security settings enabled.

---

## 🔐 Certificate Management

### Installing Trusted Certificates

```bash
# Install from repository
sudo ./main.sh load certs

# From custom repository
sudo ./main.sh load certs -c https://github.com/yourorg/certs
```

### What It Does

1. Downloads certificate repository
2. Validates certificate files
3. Installs to system trust store
4. Updates CA bundle
5. Verifies installation

### Certificate Locations

**Debian/Ubuntu**:
```
/usr/local/share/ca-certificates/
```

**CentOS/RHEL**:
```
/etc/pki/ca-trust/source/anchors/
```

### Verify Certificates

```bash
# List installed certificates
sudo ./main.sh load certs -l

# Verify certificates
sudo ./main.sh load certs -v

# Test certificate trust
openssl s_client -connect example.com:443 -CApath /etc/ssl/certs/
```

### Certificate Best Practices

1. **Verify sources**: Only install from trusted sources
2. **Regular updates**: Update certificates when they expire
3. **Monitor expiration**: Track certificate expiry dates
4. **Backup**: Keep backup of installed certificates
5. **Audit**: Regular review installed certificates

---

## 👤 User Management

### Creating Secure Users

```bash
# Create admin user with sudo access
sudo ./main.sh load user -a

# Create regular user
sudo ./main.sh load user -c alice \
  --fullname "Alice Smith" \
  --shell /bin/bash \
  --groups "developers"
```

### SSH Key Management

```bash
# Add SSH key from file
sudo ./main.sh load user -k alice ~/.ssh/id_ed25519.pub

# Add from GitHub
sudo ./main.sh load user -k alice https://github.com/alice.keys

# Add from URL
sudo ./main.sh load user -k alice https://example.com/keys/alice.pub
```

### User Security Best Practices

1. **Unique accounts**: One account per person
2. **Strong passwords**: Even with key auth
3. **Sudo access**: Use sudo, not root login
4. **Regular audits**: Review user accounts monthly
5. **Remove old accounts**: Delete when user leaves

```bash
# List all users
cat /etc/passwd | grep /bin/bash

# Check sudo users
grep -Po '^sudo.+:\K.*$' /etc/group

# Check last logins
lastlog

# Remove user
sudo userdel -r olduser
```

### Password Policies

```bash
# Install password quality tools
sudo apt-get install libpam-pwquality  # Ubuntu/Debian
sudo yum install pam_pwquality         # CentOS/RHEL

# Configure in /etc/security/pwquality.conf
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
```

---

## 🌐 Network Security

### Network Configuration

```bash
# List interfaces
sudo ./main.sh load network -l

# Configure with security in mind
sudo ./main.sh load network -c
```

### Network Security Measures

#### Disable Unused Interfaces
```bash
# List all interfaces
ip link show

# Disable interface
sudo ip link set eth1 down
```

#### Configure DNS Securely
```bash
# Use secure DNS providers
# Cloudflare
nameserver 1.1.1.1
nameserver 1.0.0.1

# Google
nameserver 8.8.8.8
nameserver 8.8.4.4

# Quad9 (security-focused)
nameserver 9.9.9.9
nameserver 149.112.112.112
```

#### Network Segmentation
```bash
# Use VLANs for isolation
sudo ./main.sh load network --add-vlan eth0 100

# Configure separate subnets
# Management: VLAN 10
# Services: VLAN 20
# Database: VLAN 30
```

---

## 📊 Security Monitoring

### Log Monitoring

```bash
# Setup log monitoring
tail -f /var/log/auth.log     # Authentication logs
tail -f /var/log/secure        # Security logs (RHEL/CentOS)
tail -f /var/log/ufw.log       # Firewall logs
tail -f /var/log/fail2ban.log  # Fail2ban logs
```

### Install Monitoring Tools

```bash
# NetData for real-time monitoring
sudo ./main.sh load netdata

# Access at http://server-ip:19999
```

### Security Alerts

Configure email alerts for security events:

```bash
# Install mail tools
sudo apt-get install mailutils  # Ubuntu/Debian
sudo yum install mailx           # CentOS/RHEL

# Test email
echo "Test" | mail -s "Alert" admin@example.com
```

### Regular Security Audits

```bash
# Check for updates
sudo apt list --upgradable

# Check listening ports
sudo netstat -tlnp
sudo ss -tlnp

# Check running services
sudo systemctl list-units --type=service --state=running

# Check failed login attempts
sudo grep "Failed password" /var/log/auth.log

# Check sudo usage
sudo grep sudo /var/log/auth.log
```

---

## ✅ Best Practices

### 1. Principle of Least Privilege

- Run services as non-root users
- Limit sudo access
- Use specific sudo commands, not ALL
- Disable unused accounts

### 2. Defense in Depth

- Multiple security layers
- Firewall + SSH hardening + kernel hardening
- Don't rely on single security control

### 3. Keep Systems Updated

```bash
# Regular updates
sudo ./main.sh load update -f

# Enable automatic security updates
sudo apt-get install unattended-upgrades  # Ubuntu/Debian
sudo yum install yum-cron                  # CentOS/RHEL
```

### 4. Monitor Everything

- Enable comprehensive logging
- Review logs regularly
- Set up alerts for security events
- Keep logs for audit trail

### 5. Regular Backups

```bash
# Backup important configs
tar -czf config-backup-$(date +%Y%m%d).tar.gz \
  /etc/ssh \
  /etc/network \
  /etc/ufw \
  ~/.config/flux
```

### 6. Document Changes

- Keep change log
- Document why changes were made
- Note who made changes and when
- Include rollback procedures

### 7. Test in Non-Production First

- Use VM or test server
- Test all changes before production
- Have rollback plan ready
- Keep console access available

---

## 📝 Security Checklists

### New Server Setup Checklist

- [ ] Run minimal OS install
- [ ] Update system: `./main.sh load update -f`
- [ ] Configure firewall: `./main.sh load firewall -w`
- [ ] Harden SSH: `./main.sh load ssh -w`
- [ ] Apply kernel hardening: `./main.sh load sysctl --apply`
- [ ] Install certificates: `./main.sh load certs`
- [ ] Create admin user: `./main.sh load user -a`
- [ ] Setup SSH keys
- [ ] Disable password auth
- [ ] Configure monitoring: `./main.sh load netdata`
- [ ] Setup fail2ban
- [ ] Enable automatic security updates
- [ ] Configure backups
- [ ] Test all services
- [ ] Document configuration

### Monthly Security Review Checklist

- [ ] Check for system updates
- [ ] Review user accounts (remove old ones)
- [ ] Audit sudo access
- [ ] Review firewall rules
- [ ] Check failed login attempts
- [ ] Review open ports
- [ ] Check for unauthorized services
- [ ] Review SSL/TLS certificates
- [ ] Update fail2ban rules
- [ ] Review logs for anomalies
- [ ] Test backup restoration
- [ ] Update documentation

### Incident Response Checklist

- [ ] Isolate affected system
- [ ] Document initial state
- [ ] Preserve logs
- [ ] Identify attack vector
- [ ] Assess damage
- [ ] Contain breach
- [ ] Eradicate threat
- [ ] Recover system
- [ ] Update security measures
- [ ] Post-incident review
- [ ] Update procedures

---

<div align="center">

**🔒 Security is a journey, not a destination. Stay vigilant! 🔒**

[← Back to README](../README.md) | [Troubleshooting →](troubleshooting.md)

</div>
