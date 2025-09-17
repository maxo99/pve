#!/bin/bash

# Grafana LXC Installation Script
# This script sets up the Grafana apt repository and installs Grafana

set -e

# Source helper functions (available via init template)
source /tmp/lxc-helpers.sh 2>/dev/null || true

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

# Setup Grafana repository using helper if available
if command -v setup_apt_repo >/dev/null 2>&1; then
    setup_apt_repo "grafana" \
        "https://packages.grafana.com/gpg.key" \
        "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://packages.grafana.com/oss/deb stable main"
else
    # Fallback to manual setup
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://packages.grafana.com/gpg.key | gpg --dearmor --yes --output /etc/apt/keyrings/grafana.gpg
    cat <<EOF >/etc/apt/sources.list.d/grafana.list
deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://packages.grafana.com/oss/deb stable main
EOF
    apt-get update
fi

# Install Grafana if not already installed
if ! dpkg -s grafana >/dev/null 2>&1; then
    echo "Installing Grafana..."
    apt-get install -y grafana
else
    echo "Grafana already installed"
fi

# Start and enable Grafana service
if command -v ensure_service_running >/dev/null 2>&1; then
    ensure_service_running "grafana-server"
else
    systemctl enable grafana-server
    systemctl start grafana-server
fi

LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "Grafana installation completed successfully."
echo "Access URL: http://${LOCAL_IP}:3000"
echo "Default credentials: admin/admin (change on first login)"
echo ""
systemctl status grafana-server --no-pager --lines=5
