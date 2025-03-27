#!/bin/bash

# Function to detect the Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    else
        echo "unknown"
    fi
}

# Function to download certificates from GitHub
download_certificates() {
    local repo_url="https://github.com/your-repo/certificates"
    local cert_dir="/tmp/certificates"
    mkdir -p $cert_dir
    wget -q -O $cert_dir/certificates.zip $repo_url/archive/main.zip
    unzip -q $cert_dir/certificates.zip -d $cert_dir
    echo $cert_dir
}

# Function to install certificates on Debian-based systems
install_certificates_debian() {
    local cert_dir=$1
    cp $cert_dir/certificates-main/*.crt /usr/local/share/ca-certificates/
    update-ca-certificates
}

# Function to install certificates on Red Hat-based systems
install_certificates_redhat() {
    local cert_dir=$1
    cp $cert_dir/certificates-main/*.crt /etc/pki/ca-trust/source/anchors/
    update-ca-trust
}

# Main script execution
distro=$(detect_distro)
cert_dir=$(download_certificates)

case $distro in
    ubuntu|debian)
        install_certificates_debian $cert_dir
        ;;
    centos|fedora|rhel)
        install_certificates_redhat $cert_dir
        ;;
    *)
        echo "Unsupported Linux distribution: $distro"
        exit 1
        ;;
esac

echo "Certificates installed successfully."

