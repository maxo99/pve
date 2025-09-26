#!/bin/bash
set -e

# Source helper functions (available via init template)
source /tmp/lxc-helpers.sh 2>/dev/null || true

APP="Traefik"
BIN_PATH="/usr/bin/traefik"
APP_DIR="/etc/traefik"
LOG_DIR="/var/log/traefik"
VERSION_FILE="/opt/traefik_version.txt"

echo "Starting $APP configuration..."

# Determine latest version (prefer helper)
LATEST_VERSION=""
if command -v get_latest_github_release >/dev/null 2>&1; then
    LATEST_VERSION=$(get_latest_github_release "traefik/traefik" | sed 's/^v//')
fi
if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION=$(curl -fsSL https://api.github.com/repos/traefik/traefik/releases/latest | jq -r '.tag_name' | sed 's/^v//')
fi
if [ -z "$LATEST_VERSION" ]; then
    echo "ERROR: Could not determine latest $APP version" >&2
    exit 1
fi

CURRENT_VERSION=""
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
fi

echo "Latest $APP: $LATEST_VERSION"
echo "Current $APP: ${CURRENT_VERSION:-none}"

# Install or update Traefik binary idempotently
if [ ! -x "$BIN_PATH" ] || [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
    echo "Installing/Updating $APP to v$LATEST_VERSION"
    TMP_TGZ="/tmp/traefik.tar.gz"
    ARCHIVE_URL="https://github.com/traefik/traefik/releases/download/v${LATEST_VERSION}/traefik_v${LATEST_VERSION}_linux_amd64.tar.gz"
    if ! curl -fsSL "$ARCHIVE_URL" -o "$TMP_TGZ"; then
        echo "ERROR: Download failed: $ARCHIVE_URL" >&2
        exit 1
    fi
    tar -xzf "$TMP_TGZ" -C /tmp traefik
    install -m 0755 /tmp/traefik "$BIN_PATH"
    rm -f "$TMP_TGZ" /tmp/traefik
    echo "$LATEST_VERSION" > "$VERSION_FILE"
fi

# Ensure directories
if command -v ensure_directory >/dev/null 2>&1; then
    ensure_directory "$APP_DIR" "root:root" "755"
    ensure_directory "$APP_DIR/conf.d" "root:root" "755"
    ensure_directory "$APP_DIR/ssl" "root:root" "700"
    ensure_directory "$LOG_DIR" "root:adm" "755"
else
    mkdir -p "$APP_DIR/conf.d" "$APP_DIR/ssl" "$LOG_DIR"
    chmod 700 "$APP_DIR/ssl"
fi

# Minimal HTTP-only config with dashboard (insecure) for first run
TRAEFIK_YAML="$APP_DIR/traefik.yaml"
cat > "$TRAEFIK_YAML" <<EOF
providers:
  file:
    directory: /etc/traefik/conf.d/

entryPoints:
  web:
    address: ':80'
  traefik:
    address: ':8080'

api:
  dashboard: true
  insecure: true

log:
  filePath: $LOG_DIR/traefik.log
  format: json
  level: INFO

accessLog:
  filePath: $LOG_DIR/traefik-access.log
  format: json
  bufferingSize: 0
EOF

# Create/refresh systemd service
SERVICE_CONTENT="[Unit]
Description=Traefik Edge Router
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=$BIN_PATH --configFile=$TRAEFIK_YAML
Restart=on-failure
ExecReload=/bin/kill -USR1 $MAINPID

[Install]
WantedBy=multi-user.target"

if command -v create_systemd_service >/dev/null 2>&1; then
    create_systemd_service "traefik" "$SERVICE_CONTENT"
else
    echo "$SERVICE_CONTENT" > /etc/systemd/system/traefik.service
    systemctl daemon-reload
    systemctl enable traefik
fi

# Start or restart if binary/config changed
if systemctl is-active --quiet traefik; then
    systemctl restart traefik || true
else
    systemctl start traefik || true
fi

sleep 3
LOCAL_IP=$(hostname -I | awk '{print $1}' || echo "localhost")
echo "$APP installed and configured."
echo "Dashboard: http://${LOCAL_IP}:8080"
systemctl status traefik --no-pager --lines=10 || true
