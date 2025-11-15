# 🤝 Contributing to Flux Framework

Thank you for considering contributing to Flux Framework! This guide will help you get started.

---

## 📋 Table of Contents

- [Code of Conduct](#-code-of-conduct)
- [How Can I Contribute?](#-how-can-i-contribute)
- [Development Setup](#-development-setup)
- [Module Development](#-module-development)
- [Code Style Guidelines](#-code-style-guidelines)
- [Testing](#-testing)
- [Documentation](#-documentation)
- [Pull Request Process](#-pull-request-process)
- [Community](#-community)

---

## 📜 Code of Conduct

### Our Pledge

We pledge to make participation in our project a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards

**Positive behavior includes:**
- Using welcoming and inclusive language
- Being respectful of differing viewpoints
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards others

**Unacceptable behavior includes:**
- Trolling, insulting/derogatory comments, and personal attacks
- Public or private harassment
- Publishing others' private information
- Other conduct which could reasonably be considered inappropriate

---

## 💡 How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues. When creating a bug report, include as many details as possible:

**Bug Report Template:**
```markdown
## Bug Description
Clear and concise description of what the bug is.

## To Reproduce
Steps to reproduce the behavior:
1. Run '...'
2. See error

## Expected Behavior
What you expected to happen.

## Actual Behavior
What actually happened.

## Environment
- OS: [e.g., Ubuntu 22.04]
- Flux Version: [e.g., 3.0.0]
- Bash Version: [e.g., 5.1.16]

## Logs
```bash
Relevant log output
```

## Additional Context
Any other information about the problem.
```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

**Enhancement Template:**
```markdown
## Feature Description
Clear description of the feature.

## Problem It Solves
What problem does this solve?

## Proposed Solution
How should this work?

## Alternatives Considered
Other solutions you've thought about.

## Additional Context
Mockups, examples, etc.
```

### Code Contributions

1. **Small fixes**: Submit PRs directly
2. **New features**: Open an issue first to discuss
3. **Major changes**: Discuss in GitHub Discussions first

---

## 🛠️ Development Setup

### Prerequisites

```bash
# Required tools
git
bash 4.0+
shellcheck (for linting)
bats (for testing)

# Install shellcheck
sudo apt-get install shellcheck  # Ubuntu/Debian
sudo yum install ShellCheck      # CentOS/RHEL

# Install bats
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### Fork and Clone

```bash
# Fork the repository on GitHub first

# Clone your fork
git clone https://github.com/YOUR-USERNAME/flux-framework.git
cd flux-framework

# Add upstream remote
git remote add upstream https://github.com/ethanbissbort/flux-framework.git

# Verify remotes
git remote -v
```

### Create a Branch

```bash
# Update your fork
git checkout main
git pull upstream main

# Create feature branch
git checkout -b feature/amazing-feature

# Or bugfix branch
git checkout -b fix/bug-description
```

---

## 🧩 Module Development

### Module Structure

All modules follow this pattern:

```bash
#!/bin/bash

# flux-example-module.sh - Brief description
# Version: 1.0.0
# Detailed description of what this module does

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

readonly CONFIG_VAR="value"
readonly DEFAULT_SETTING="default"

# =============================================================================
# MODULE FUNCTIONS
# =============================================================================

# Main module function
do_something() {
    local param="$1"

    log_info "Doing something with: $param"

    # Module logic here

    log_success "Operation completed"
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

show_usage() {
    cat << EOF
Module Name - Description

Usage: $(basename "$0") [OPTIONS]

Options:
    -h, --help              Show this help message
    -v, --verbose           Verbose output
    -f, --force             Force operation

Examples:
    $(basename "$0") --option value

EOF
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                LOG_LEVEL=0
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Main logic
    do_something
}

# Run main function
main "$@"
```

### Module Naming Convention

- **File name**: `flux-modulename-module.sh`
- **Module name**: `modulename` (used in `./main.sh load modulename`)
- **Function names**: Use snake_case
- **Constants**: Use UPPER_CASE

### Using Helper Functions

```bash
# Logging
log_debug "Debug message"
log_info "Info message"
log_warn "Warning message"
log_error "Error message"
log_success "Success message"

# User input
prompt_yes_no "Continue?" "y"
prompt_with_validation "Enter IP" "validate_ip"

# Validation
validate_ip "192.168.1.1"
validate_hostname "server.example.com"
validate_port "8080"
validate_email "user@example.com"

# System checks
check_command "git"
require_root
detect_package_manager
check_internet

# File operations
backup_file "/etc/config"
safe_write_file "/etc/config" "$content"

# UI helpers
print_header "Section Title"
print_separator "="
show_spinner $pid "Processing"

# Package management
install_package "package-name"
is_package_installed "package-name"

# Network helpers
get_default_gateway
get_primary_dns
```

---

## 📏 Code Style Guidelines

### Shell Script Style

Follow these conventions:

#### Variables
```bash
# Constants (readonly)
readonly CONSTANT_VALUE="value"

# Global variables
global_variable="value"

# Local variables
local local_variable="value"

# Arrays
declare -a my_array=("item1" "item2")
declare -A my_map=(["key"]="value")
```

#### Functions
```bash
# Function documentation
# Description of what function does
# Arguments:
#   $1 - Description of first argument
#   $2 - Description of second argument
# Returns:
#   0 on success, 1 on failure
function_name() {
    local param1="$1"
    local param2="$2"

    # Function body

    return 0
}
```

#### Conditionals
```bash
# Use [[ ]] for tests
if [[ "$var" == "value" ]]; then
    # do something
elif [[ "$var" == "other" ]]; then
    # do something else
else
    # default
fi

# Use && and || for simple conditions
[[ -f "$file" ]] && log_info "File exists"
[[ -z "$var" ]] || log_error "Variable is set"
```

#### Loops
```bash
# For loop
for item in "${array[@]}"; do
    echo "$item"
done

# While loop
while IFS= read -r line; do
    echo "$line"
done < file.txt

# C-style for loop
for ((i=0; i<10; i++)); do
    echo "$i"
done
```

### Linting

Run shellcheck before committing:

```bash
# Check specific file
shellcheck modules/flux-example-module.sh

# Check all modules
shellcheck modules/*.sh

# Auto-fix simple issues
shellcheck -f diff modules/*.sh | patch
```

### Common ShellCheck Rules

- Use `"$var"` instead of `$var`
- Use `[[ ]]` instead of `[ ]`
- Check exit codes: `if cmd; then` not `if [ $? -eq 0 ]; then`
- Avoid `eval` when possible
- Quote variables in loops
- Use `local` for function variables

---

## 🧪 Testing

### Manual Testing

Test your module on multiple distributions:

```bash
# Test on Ubuntu
docker run -it --rm -v $(pwd):/flux ubuntu:22.04 bash
cd /flux
./main.sh load yourmodule

# Test on CentOS
docker run -it --rm -v $(pwd):/flux centos:8 bash
cd /flux
./main.sh load yourmodule

# Test on Debian
docker run -it --rm -v $(pwd):/flux debian:12 bash
cd /flux
./main.sh load yourmodule
```

### Syntax Testing

```bash
# Syntax check
bash -n modules/flux-example-module.sh

# Verbose syntax check
bash -xn modules/flux-example-module.sh
```

### Integration Testing

Test module with main.sh:

```bash
# Test module loading
./main.sh load yourmodule --help

# Test module execution
sudo ./main.sh load yourmodule

# Test in workflow
sudo ./main.sh workflow test
```

### Test Checklist

- [ ] Module loads successfully
- [ ] Help text displays correctly
- [ ] All arguments work as expected
- [ ] Error handling works
- [ ] Backup functionality works
- [ ] Logs are generated correctly
- [ ] Works on Ubuntu
- [ ] Works on Debian
- [ ] Works on CentOS/RHEL
- [ ] Idempotent (can run multiple times)
- [ ] Shellcheck passes
- [ ] No syntax errors

---

## 📚 Documentation

### Module Documentation

Every module needs:

1. **Header comment**:
```bash
# flux-example-module.sh - Brief description
# Version: 1.0.0
# Full description of module functionality
```

2. **Help text**:
```bash
show_usage() {
    cat << EOF
Module Name - Description

Usage: $(basename "$0") [OPTIONS]

Options:
    -h, --help         Show help
    -v, --verbose      Verbose output

Examples:
    $(basename "$0") --option value

EOF
}
```

3. **Function documentation**:
```bash
# Function description
# Arguments:
#   $1 - Parameter description
# Returns:
#   0 on success, 1 on failure
function_name() {
    # implementation
}
```

### Update README

If adding new features, update:
- README.md
- docs/module-reference.md
- docs/quick-start.md (if applicable)

---

## 🔄 Pull Request Process

### Before Submitting

1. **Update your branch**:
```bash
git checkout main
git pull upstream main
git checkout your-branch
git rebase main
```

2. **Test thoroughly**:
```bash
# Run shellcheck
shellcheck modules/*.sh

# Test module
./main.sh load yourmodule

# Test on different distros
```

3. **Update documentation**:
```bash
# Add to CHANGELOG.md
# Update relevant docs
```

4. **Commit with meaningful messages**:
```bash
git add modules/flux-example-module.sh
git commit -m "Add example module for X functionality

- Implements feature Y
- Adds support for Z
- Fixes issue #123"
```

### PR Template

```markdown
## Description
Brief description of changes.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tested on Ubuntu 22.04
- [ ] Tested on Debian 12
- [ ] Tested on CentOS Stream 9
- [ ] Shellcheck passes
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings generated
- [ ] Tests pass

## Related Issues
Fixes #(issue number)

## Screenshots (if applicable)
```

### Review Process

1. **Automated checks** run first
2. **Maintainer review** (usually within 1 week)
3. **Address feedback** if any
4. **Approval and merge**

---

## 👥 Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and community discussion
- **Pull Requests**: Code contributions

### Getting Help

- Check [documentation](../README.md)
- Search [existing issues](https://github.com/ethanbissbort/flux-framework/issues)
- Ask in [Discussions](https://github.com/ethanbissbort/flux-framework/discussions)

### Recognition

Contributors are recognized in:
- README.md acknowledgments
- Release notes
- GitHub contributors page

---

## 🎉 Thank You!

Every contribution, no matter how small, helps make Flux Framework better for everyone. We appreciate your time and effort!

**Happy Contributing! 🚀**

<div align="center">

[← Back to README](../README.md) | [Security Guide →](security-guide.md)

</div>
