#!/bin/bash
# InfluxDB v1.8 installer - assumes gnupg, curl, ca-certificates present

set -e

# Source helper functions (available via init template)
source /tmp/lxc-helpers.sh 2>/dev/null || true

echo "Setting up InfluxDB v1.8..."

# Determine OS codename
if [ -f /etc/os-release ]; then
    . /etc/os-release
    CODENAME="${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || echo jammy)}"
else
    CODENAME="jammy"
fi

echo "Detected OS codename: $CODENAME"

# Setup InfluxDB repository using helper if available
if command -v setup_apt_repo >/dev/null 2>&1; then
    # Note: InfluxDB v1.8 uses apt-key which is deprecated but still required
    if ! apt-key list | grep -q "InfluxData" 2>/dev/null; then
        curl -fsSL https://repos.influxdata.com/influxdata-archive_compat.key | apt-key add -
    fi
    
    if [ ! -f /etc/apt/sources.list.d/influxdb.list ]; then
        echo "deb https://repos.influxdata.com/ubuntu ${CODENAME} stable" | tee /etc/apt/sources.list.d/influxdb.list
        apt-get update
    fi
else
    # Fallback to manual setup
    if ! apt-key list | grep -q "InfluxData" 2>/dev/null; then
        curl -fsSL https://repos.influxdata.com/influxdata-archive_compat.key | apt-key add -
    fi
    
    if [ ! -f /etc/apt/sources.list.d/influxdb.list ]; then
        echo "deb https://repos.influxdata.com/ubuntu ${CODENAME} stable" | tee /etc/apt/sources.list.d/influxdb.list
        apt-get update
    fi
fi

# Install InfluxDB if not already installed
if ! dpkg -s influxdb >/dev/null 2>&1; then
    echo "Installing InfluxDB v1.8..."
    apt-get install -y --no-install-recommends influxdb
else
    echo "InfluxDB already installed"
fi

# Start and enable InfluxDB service
if command -v ensure_service_running >/dev/null 2>&1; then
    ensure_service_running "influxdb"
else
    systemctl enable influxdb
    systemctl start influxdb
fi

LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "InfluxDB v1.8 installation completed successfully."
echo "Connection details:"
echo "  Host: $LOCAL_IP"
echo "  Port: 8086"
echo "  Web UI: http://$LOCAL_IP:8083 (if enabled)"
echo ""
systemctl status influxdb --no-pager --lines=5