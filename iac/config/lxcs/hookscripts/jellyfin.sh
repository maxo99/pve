#!/bin/bash

# Jellyfin LXC Installation Script
# This script sets up the Jellyfin repository and installs Jellyfin

set -e

# Source helper functions (available via init template)
source /tmp/lxc-helpers.sh 2>/dev/null || true

echo "Setting up Jellyfin repository..."

# Determine OS type and version for repository
if [ -f /etc/os-release ]; then
    . /etc/os-release
    PCT_OSTYPE="${ID}"
    PCT_OSVERSION="${VERSION_CODENAME:-${UBUNTU_CODENAME}}"
else
    echo "ERROR: Cannot determine OS type"
    exit 1
fi

echo "Detected OS: $PCT_OSTYPE, Version: $PCT_OSVERSION"

# Setup Jellyfin repository using modern sources format
if command -v ensure_directory >/dev/null 2>&1; then
    ensure_directory "/etc/apt/keyrings" "root:root" "755"
else
    mkdir -p /etc/apt/keyrings
fi

# Download repository key if not exists
if [ ! -f /etc/apt/keyrings/jellyfin.gpg ]; then
    curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | gpg --dearmor --yes --output /etc/apt/keyrings/jellyfin.gpg
fi

# Create repository sources file if not exists
JELLYFIN_SOURCES="/etc/apt/sources.list.d/jellyfin.sources"
if [ ! -f "$JELLYFIN_SOURCES" ]; then
    cat <<EOF >"$JELLYFIN_SOURCES"
Types: deb
URIs: https://repo.jellyfin.org/ubuntu
Suites: jammy
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/jellyfin.gpg
EOF
    echo "Jellyfin repository setup complete."
    apt-get update
else
    echo "Jellyfin repository already configured"
fi

# Install Jellyfin and hardware acceleration packages if not already installed
JELLYFIN_PACKAGES=(va-driver-all ocl-icd-libopencl1 intel-opencl-icd vainfo intel-gpu-tools jellyfin)
PACKAGES_TO_INSTALL=()

for pkg in "${JELLYFIN_PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        PACKAGES_TO_INSTALL+=("$pkg")
    fi
done

if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
    echo "Installing Jellyfin and hardware acceleration packages: ${PACKAGES_TO_INSTALL[*]}"
    apt-get install -y "${PACKAGES_TO_INSTALL[@]}"
else
    echo "Jellyfin and required packages already installed"
fi

# Start and enable Jellyfin service
if command -v ensure_service_running >/dev/null 2>&1; then
    ensure_service_running "jellyfin"
else
    systemctl enable jellyfin
    systemctl start jellyfin
fi

LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "Jellyfin installation completed successfully."
echo "Access URL: http://$LOCAL_IP:8096"
echo "Setup wizard will guide you through initial configuration"
echo ""
systemctl status jellyfin --no-pager --lines=5
