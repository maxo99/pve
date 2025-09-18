#!/bin/bash
set -e

# Source helper functions (available via init template)
source /tmp/lxc-helpers.sh 2>/dev/null || true

APP="Glance"
APP_DIR="/opt/glance"
VERSION_FILE="/opt/glance_version.txt"

echo "Starting $APP configuration..."

# Get latest version from GitHub
LATEST_VERSION=""
if command -v get_latest_github_release >/dev/null 2>&1; then
    LATEST_VERSION=$(get_latest_github_release "glanceapp/glance" || echo "")
fi

# Fallback if helper function fails
if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION=$(curl -fsSL https://api.github.com/repos/glanceapp/glance/releases/latest | jq -r '.tag_name' | sed 's/^v//')
fi

if [ -z "$LATEST_VERSION" ]; then
    echo "ERROR: Could not determine latest Glance version"
    exit 1
fi

echo "Latest $APP version: $LATEST_VERSION"

# Check if already installed and up to date
CURRENT_VERSION=""
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
fi

echo "Current $APP version: ${CURRENT_VERSION:-none}"

# Skip if already up to date and service is running
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ] && systemctl is-active --quiet glance 2>/dev/null; then
    echo "$APP is already up to date and running"
    exit 0
fi

# Setup application directory
if command -v ensure_directory >/dev/null 2>&1; then
    ensure_directory "$APP_DIR" "root:root" "755"
else
    mkdir -p "$APP_DIR"
fi

echo "Installing $APP v$LATEST_VERSION..."

# Download and extract Glance binary
DOWNLOAD_URL="https://github.com/glanceapp/glance/releases/download/v${LATEST_VERSION}/glance-linux-amd64.tar.gz"
TEMP_FILE="/tmp/glance-linux-amd64.tar.gz"

if ! curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_FILE"; then
    echo "ERROR: Failed to download Glance from $DOWNLOAD_URL"
    exit 1
fi

# Extract the binary
cd /tmp
if ! tar -xzf "$TEMP_FILE"; then
    echo "ERROR: Failed to extract Glance archive"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Install the binary
if ! install -m 755 glance "$APP_DIR/glance"; then
    echo "ERROR: Failed to install Glance binary"
    rm -f "$TEMP_FILE" glance
    exit 1
fi

# Cleanup temporary files
rm -f "$TEMP_FILE" glance

# Create basic configuration
cat <<EOF > "$APP_DIR/glance.yml"
pages:
  - name: Startpage
    width: slim
    hide-desktop-navigation: true
    center-vertically: true
    columns:
      - size: full
        widgets:
          - type: search
            autofocus: true
          - type: bookmarks
            groups:
              - title: General
                links:
                  - title: Google
                    url: https://www.google.com/
                  - title: Helper Scripts
                    url: https://github.com/community-scripts/ProxmoxVE
EOF

echo "Created basic Glance configuration"

# Create systemd service
SERVICE_CONTENT="[Unit]
Description=Glance Daemon
After=network.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/glance --config $APP_DIR/glance.yml
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target"

if command -v create_systemd_service >/dev/null 2>&1; then
    create_systemd_service "glance" "$SERVICE_CONTENT"
else
    echo "$SERVICE_CONTENT" > /etc/systemd/system/glance.service
    systemctl daemon-reload
    systemctl enable glance
fi

# Track version
if command -v track_version >/dev/null 2>&1; then
    track_version "glance" "$LATEST_VERSION"
else
    echo "$LATEST_VERSION" > "$VERSION_FILE"
fi

# Start service
if command -v ensure_service_running >/dev/null 2>&1; then
    ensure_service_running "glance"
else
    systemctl start glance
fi

# Show access information
LOCAL_IP=$(hostname -I | awk '{print $1}' || echo "localhost")
echo "$APP installed successfully!"
echo "Access URL: http://${LOCAL_IP}:8080"

# Show service status
sleep 3
systemctl status glance --no-pager --lines=10 || true
