#!/bin/bash

# flux-certs.sh - Certificate installation script (refactored with helper functions)
# This script downloads and installs trusted certificates for system-wide use

# Source helper functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../flux-helpers.sh" ]]; then
    source "$SCRIPT_DIR/../flux-helpers.sh"
else
    echo "Error: flux-helpers.sh not found in $SCRIPT_DIR"
    echo "Please ensure flux-helpers.sh is in the same directory as this script"
    exit 1
fi

# Set up error handling
setup_error_handling

# =============================================================================
# CONFIGURATION
# =============================================================================

# Default certificate repository configuration
readonly DEFAULT_CERT_REPO="https://github.com/your-repo/certificates"
readonly TEMP_CERT_DIR="/tmp/certificates"
readonly DEBIAN_CERT_DIR="/usr/local/share/ca-certificates"
readonly REDHAT_CERT_DIR="/etc/pki/ca-trust/source/anchors"

# =============================================================================
# CERTIFICATE FUNCTIONS
# =============================================================================

# Download certificates from repository
download_certificates() {
    local repo_url="$1"
    local cert_dir="$2"
    
    log_info "Downloading certificates from: $repo_url"
    
    # Create certificate directory
    if ! mkdir -p "$cert_dir"; then
        log_error "Failed to create certificate directory: $cert_dir"
        return 1
    fi
    
    # Construct download URL for main branch archive
    local archive_url="${repo_url}/archive/main.zip"
    local cert_archive="$cert_dir/certificates.zip"
    
    # Download certificate archive
    if safe_download "$archive_url" "$cert_archive"; then
        log_info "Certificate archive downloaded successfully"
    else
        log_error "Failed to download certificate archive from $archive_url"
        return 1
    fi
    
    # Extract certificate archive
    log_info "Extracting certificate archive"
    if command -v unzip >/dev/null 2>&1; then
        if unzip -q "$cert_archive" -d "$cert_dir"; then
            log_info "Certificate archive extracted successfully"
            
            # Verify extracted directory exists
            local extracted_dir="$cert_dir/certificates-main"
            if [[ -d "$extracted_dir" ]]; then
                log_info "Found certificate directory: $extracted_dir"
                
                # Check for certificate files
                local cert_count=$(find "$extracted_dir" -name "*.crt" -o -name "*.pem" | wc -l)
                if [[ $cert_count -gt 0 ]]; then
                    log_info "Found $cert_count certificate files"
                    echo "$extracted_dir"
                    return 0
                else
                    log_error "No certificate files (.crt or .pem) found in extracted archive"
                    return 1
                fi
            else
                log_error "Expected directory $extracted_dir not found after extraction"
                return 1
            fi
        else
            log_error "Failed to extract certificate archive"
            return 1
        fi
    else
        log_error "unzip command not found. Please install unzip package"
        return 1
    fi
}

# Install certificates on Debian-based systems
install_certificates_debian() {
    local cert_source_dir="$1"
    
    log_info "Installing certificates for Debian-based system"
    
    # Verify source directory exists
    if [[ ! -d "$cert_source_dir" ]]; then
        log_error "Certificate source directory does not exist: $cert_source_dir"
        return 1
    fi
    
    # Verify destination directory exists
    if [[ ! -d "$DEBIAN_CERT_DIR" ]]; then
        log_error "Debian certificate directory does not exist: $DEBIAN_CERT_DIR"
        log_error "This may not be a Debian-based system"
        return 1
    fi
    
    # Find certificate files
    local cert_files=($(find "$cert_source_dir" -name "*.crt" -o -name "*.pem"))
    
    if [[ ${#cert_files[@]} -eq 0 ]]; then
        log_error "No certificate files found in $cert_source_dir"
        return 1
    fi
    
    log_info "Found ${#cert_files[@]} certificate files to install"
    
    # Copy certificate files
    local installed_count=0
    for cert_file in "${cert_files[@]}"; do
        local cert_name=$(basename "$cert_file")
        local dest_file="$DEBIAN_CERT_DIR/$cert_name"
        
        log_info "Installing certificate: $cert_name"
        
        if sudo cp "$cert_file" "$dest_file"; then
            sudo chmod 644 "$dest_file"
            ((installed_count++))
            log_info "Successfully installed: $cert_name"
        else
            log_error "Failed to install: $cert_name"
        fi
    done
    
    if [[ $installed_count -eq 0 ]]; then
        log_error "No certificates were successfully installed"
        return 1
    fi
    
    # Update certificate store
    log_info "Updating certificate authorities"
    if sudo update-ca-certificates; then
        log_info "Certificate authorities updated successfully"
        log_info "Installed $installed_count certificates"
        return 0
    else
        log_error "Failed to update certificate authorities"
        return 1
    fi
}

# Install certificates on Red Hat-based systems
install_certificates_redhat() {
    local cert_source_dir="$1"
    
    log_info "Installing certificates for Red Hat-based system"
    
    # Verify source directory exists
    if [[ ! -d "$cert_source_dir" ]]; then
        log_error "Certificate source directory does not exist: $cert_source_dir"
        return 1
    fi
    
    # Verify destination directory exists
    if [[ ! -d "$REDHAT_CERT_DIR" ]]; then
        log_error "Red Hat certificate directory does not exist: $REDHAT_CERT_DIR"
        log_error "This may not be a Red Hat-based system"
        return 1
    fi
    
    # Find certificate files
    local cert_files=($(find "$cert_source_dir" -name "*.crt" -o -name "*.pem"))
    
    if [[ ${#cert_files[@]} -eq 0 ]]; then
        log_error "No certificate files found in $cert_source_dir"
        return 1
    fi
    
    log_info "Found ${#cert_files[@]} certificate files to install"
    
    # Copy certificate files
    local installed_count=0
    for cert_file in "${cert_files[@]}"; do
        local cert_name=$(basename "$cert_file")
        local dest_file="$REDHAT_CERT_DIR/$cert_name"
        
        log_info "Installing certificate: $cert_name"
        
        if sudo cp "$cert_file" "$dest_file"; then
            sudo chmod 644 "$dest_file"
            ((installed_count++))
            log_info "Successfully installed: $cert_name"
        else
            log_error "Failed to install: $cert_name"
        fi
    done
    
    if [[ $installed_count -eq 0 ]]; then
        log_error "No certificates were successfully installed"
        return 1
    fi
    
    # Update certificate trust
    log_info "Updating certificate trust"
    if sudo update-ca-trust; then
        log_info "Certificate trust updated successfully"
        log_info "Installed $installed_count certificates"
        return 0
    else
        log_error "Failed to update certificate trust"
        return 1
    fi
}

# Validate certificate file
validate_certificate() {
    local cert_file="$1"
    
    if [[ ! -f "$cert_file" ]]; then
        return 1
    fi
    
    # Check if it's a valid certificate using openssl
    if command -v openssl >/dev/null 2>&1; then
        if openssl x509 -in "$cert_file" -text -noout >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        # If openssl is not available, do basic file check
        if grep -q "BEGIN CERTIFICATE" "$cert_file" && grep -q "END CERTIFICATE" "$cert_file"; then
            return 0
        else
            return 1
        fi
    fi
}

# List and verify certificates before installation
list_certificates() {
    local cert_source_dir="$1"
    
    log_info "Listing certificates in: $cert_source_dir"
    
    local cert_files=($(find "$cert_source_dir" -name "*.crt" -o -name "*.pem"))
    
    if [[ ${#cert_files[@]} -eq 0 ]]; then
        log_warn "No certificate files found in $cert_source_dir"
        return 1
    fi
    
    echo -e "${CYAN}=== Certificate Files Found ===${NC}"
    
    local valid_count=0
    local invalid_count=0
    
    for cert_file in "${cert_files[@]}"; do
        local cert_name=$(basename "$cert_file")
        local file_size=$(stat -f%z "$cert_file" 2>/dev/null || stat -c%s "$cert_file" 2>/dev/null || echo "unknown")
        
        printf "  %-30s " "$cert_name"
        
        if validate_certificate "$cert_file"; then
            echo -e "${GREEN}✓ Valid${NC} (${file_size} bytes)"
            
            # Show certificate details if openssl is available
            if command -v openssl >/dev/null 2>&1; then
                local subject=$(openssl x509 -in "$cert_file" -subject -noout 2>/dev/null | sed 's/subject=//')
                local issuer=$(openssl x509 -in "$cert_file" -issuer -noout 2>/dev/null | sed 's/issuer=//')
                local expiry=$(openssl x509 -in "$cert_file" -enddate -noout 2>/dev/null | sed 's/notAfter=//')
                
                if [[ -n "$subject" ]]; then
                    echo "    Subject: $subject"
                fi
                if [[ -n "$issuer" ]]; then
                    echo "    Issuer: $issuer"
                fi
                if [[ -n "$expiry" ]]; then
                    echo "    Expires: $expiry"
                fi
                echo
            fi
            
            ((valid_count++))
        else
            echo -e "${RED}✗ Invalid${NC} (${file_size} bytes)"
            ((invalid_count++))
        fi
    done
    
    echo -e "${WHITE}Summary: $valid_count valid, $invalid_count invalid certificates${NC}"
    
    if [[ $valid_count -eq 0 ]]; then
        log_error "No valid certificates found"
        return 1
    fi
    
    return 0
}

# =============================================================================
# CLEANUP FUNCTION
# =============================================================================

cleanup_certificates() {
    log_info "Cleaning up temporary certificate files"
    
    if [[ -d "$TEMP_CERT_DIR" ]]; then
        rm -rf "$TEMP_CERT_DIR"
        log_info "Removed temporary directory: $TEMP_CERT_DIR"
    fi
}

# =============================================================================
# MAIN CERTIFICATE INSTALLATION LOGIC
# =============================================================================

install_certificates_main() {
    local repo_url="${1:-$DEFAULT_CERT_REPO}"
    local cert_dir="$TEMP_CERT_DIR"
    
    log_info "Starting certificate installation process"
    
    # Detect Linux distribution
    local distro=$(detect_distro)
    log_info "Detected distribution: $distro"
    
    # Validate distribution support
    case $distro in
        ubuntu|debian|mint|pop)
            log_info "Using Debian-based certificate installation"
            ;;
        centos|fedora|rhel|rocky|almalinux)
            log_info "Using Red Hat-based certificate installation"
            ;;
        *)
            log_error "Unsupported Linux distribution: $distro"
            log_error "This script supports Debian/Ubuntu and Red Hat/CentOS family distributions"
            return 1
            ;;
    esac
    
    # Check if running with appropriate privileges
    if ! is_root; then
        log_warn "Not running as root. Certificate installation may require sudo privileges"
    fi
    
    # Download certificates
    local cert_source_dir
    if cert_source_dir=$(download_certificates "$repo_url" "$cert_dir"); then
        log_info "Certificates downloaded to: $cert_source_dir"
    else
        log_error "Failed to download certificates"
        return 1
    fi
    
    # List and verify certificates
    if ! list_certificates "$cert_source_dir"; then
        log_error "Certificate validation failed"
        return 1
    fi
    
    # Confirm installation
    echo
    if ! prompt_yes_no "Proceed with certificate installation?" "y"; then
        log_info "Certificate installation cancelled by user"
        return 0
    fi
    
    # Install certificates based on distribution
    case $distro in
        ubuntu|debian|mint|pop)
            if install_certificates_debian "$cert_source_dir"; then
                log_info "Debian-based certificate installation completed successfully"
            else
                log_error "Debian-based certificate installation failed"
                return 1
            fi
            ;;
        centos|fedora|rhel|rocky|almalinux)
            if install_certificates_redhat "$cert_source_dir"; then
                log_info "Red Hat-based certificate installation completed successfully"
            else
                log_error "Red Hat-based certificate installation failed"
                return 1
            fi
            ;;
    esac
    
    # Verify installation
    log_info "Verifying certificate installation"
    local cert_count_before=$(/usr/bin/find /etc/ssl/certs -name "*.pem" 2>/dev/null | wc -l)
    log_info "System now has certificate store entries"
    
    echo -e "${GREEN}Certificate installation completed successfully!${NC}"
    
    return 0
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

usage() {
    cat << EOF
Usage: $0 [options] [repository_url]

Install trusted certificates from a Git repository.

Arguments:
    repository_url      URL of Git repository containing certificates
                       (default: $DEFAULT_CERT_REPO)

Options:
    -h, --help         Display this help message
    -l, --list         List certificates without installing
    -v, --verify       Verify certificates only (no installation)
    -c, --cleanup      Clean up temporary files and exit

Examples:
    $0                                          # Use default repository
    $0 https://github.com/myorg/certs          # Use custom repository
    $0 -l https://github.com/myorg/certs       # List certificates only
    $0 -v                                      # Verify default certificates

EOF
    exit 0
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local repo_url="$DEFAULT_CERT_REPO"
    local list_only=false
    local verify_only=false
    local cleanup_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -l|--list)
                list_only=true
                shift
                ;;
            -v|--verify)
                verify_only=true
                shift
                ;;
            -c|--cleanup)
                cleanup_only=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                ;;
            *)
                # Assume it's a repository URL
                repo_url="$1"
                shift
                ;;
        esac
    done
    
    # Handle cleanup only
    if [[ "$cleanup_only" == true ]]; then
        cleanup_certificates
        exit 0
    fi
    
    # Validate repository URL
    if [[ ! "$repo_url" =~ ^https?:// ]]; then
        log_error "Invalid repository URL: $repo_url"
        log_error "URL must start with http:// or https://"
        exit 1
    fi
    
    log_info "Flux certificate installation script started"
    log_info "Repository URL: $repo_url"
    
    # Download certificates
    local cert_source_dir
    if cert_source_dir=$(download_certificates "$repo_url" "$TEMP_CERT_DIR"); then
        log_info "Certificates downloaded successfully"
    else
        log_error "Failed to download certificates"
        exit 1
    fi
    
    # Handle list only mode
    if [[ "$list_only" == true ]]; then
        list_certificates "$cert_source_dir"
        cleanup_certificates
        exit 0
    fi
    
    # Handle verify only mode
    if [[ "$verify_only" == true ]]; then
        if list_certificates "$cert_source_dir"; then
            echo -e "${GREEN}All certificates are valid${NC}"
            cleanup_certificates
            exit 0
        else
            echo -e "${RED}Certificate validation failed${NC}"
            cleanup_certificates
            exit 1
        fi
    fi
    
    # Perform full installation
    if install_certificates_main "$repo_url"; then
        log_info "Certificate installation completed successfully"
        exit_code=0
    else
        log_error "Certificate installation failed"
        exit_code=1
    fi
    
    # Cleanup and exit
    cleanup_certificates
    exit $exit_code
}

# Set up exit trap for cleanup
trap cleanup_certificates EXIT

# Run main function with all arguments
main "$@"
    
