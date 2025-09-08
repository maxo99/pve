#!/bin/bash

# Grafana LXC Installation Script
# This script sets up the Grafana apt repository and installs Grafana

set -e

echo "Setting up Grafana repository..."

# Determine OS type and version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DIST_ID="${ID}"
    DIST_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME}}"
else
    echo "ERROR: Cannot determine OS type"
    exit 1
fi

echo "Detected OS: $DIST_ID, Codename: $DIST_CODENAME"

# Ensure keyrings directory exists
mkdir -p /etc/apt/keyrings

# Add Grafana GPG key
curl -fsSL https://packages.grafana.com/gpg.key | gpg --dearmor --yes --output /etc/apt/keyrings/grafana.gpg

# Create sources.list entry
cat <<EOF >/etc/apt/sources.list.d/grafana.list
deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://packages.grafana.com/oss/deb stable main
EOF

apt-get update

# Install Grafana
apt-get install -y grafana

# Enable and start Grafana service
systemctl enable grafana-server
systemctl start grafana-server

echo "Grafana installation completed successfully."
