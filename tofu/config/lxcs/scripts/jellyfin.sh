#!/bin/bash

# Jellyfin LXC Installation Script
# This script sets up the Jellyfin repository and installs Jellyfin

set -e

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

# Create keyring directory if it doesn't exist
if [[ ! -d /etc/apt/keyrings ]]; then
    mkdir -p /etc/apt/keyrings
fi

# Download and install the repository signing key
curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | gpg --dearmor --yes --output /etc/apt/keyrings/jellyfin.gpg

# Create the repository sources file
cat <<EOF >/etc/apt/sources.list.d/jellyfin.sources
Types: deb
URIs: https://repo.jellyfin.org/ubuntu
Suites: jammy
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/jellyfin.gpg
EOF

echo "Jellyfin repository setup complete."

# Update package lists to include the new repository
apt-get update

echo "Installing Jellyfin and hardware acceleration packages..."
apt-get install -y va-driver-all ocl-icd-libopencl1 intel-opencl-icd vainfo intel-gpu-tools jellyfin

echo "Jellyfin installation completed successfully."
