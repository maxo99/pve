#!/bin/bash
set -e

# Source helper functions (available via init template)
source /tmp/lxc-helpers.sh 2>/dev/null || true

# Homepage Dashboard installer/updater
APP="Homepage"
APP_DIR="/opt/homepage"
APP_USER="homepage"
NODE_MAJOR=22

# Check if already installed and get version
VERSION_FILE="/opt/homepage_version.txt"
CURRENT_VERSION=""
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
fi

# Get latest version
if command -v get_latest_github_release >/dev/null 2>&1; then
    LATEST_VERSION=$(get_latest_github_release "gethomepage/homepage")
else
    LATEST_VERSION=$(curl -fsSL https://api.github.com/repos/gethomepage/homepage/releases/latest | jq -r '.tag_name' | sed 's/^v//')
fi

echo "Current version: ${CURRENT_VERSION:-none}"
echo "Latest version: $LATEST_VERSION"

# Skip if already up to date
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ] && systemctl is-active --quiet homepage 2>/dev/null; then
    echo "Homepage is already up to date and running"
    exit 0
fi

# Use helper functions if available
if command -v setup_nodejs >/dev/null 2>&1; then
    setup_nodejs "$NODE_MAJOR"
    setup_pnpm "latest"
    ensure_user "$APP_USER" "/home/$APP_USER" "/bin/bash" "true"
else
    # Fallback to manual setup
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -
    apt-get install -y nodejs
    npm install -g pnpm@latest
    useradd -r -m -d "/home/$APP_USER" -s /bin/bash "$APP_USER" || true
fi

# Setup directories
if command -v ensure_directory >/dev/null 2>&1; then
    ensure_directory "$APP_DIR" "$APP_USER:$APP_USER" "755"
    ensure_directory "/home/$APP_USER/.local/share/pnpm" "$APP_USER:$APP_USER" "755"
    ensure_directory "/home/$APP_USER/.cache" "$APP_USER:$APP_USER" "755"
else
    mkdir -p "$APP_DIR" "/home/$APP_USER/.local/share/pnpm" "/home/$APP_USER/.cache"
    chown -R "$APP_USER:$APP_USER" "$APP_DIR" "/home/$APP_USER"
fi

# Download and install/update
echo "Installing Homepage v$LATEST_VERSION"
cd /tmp
curl -fsSL "https://github.com/gethomepage/homepage/archive/refs/tags/v${LATEST_VERSION}.tar.gz" -o homepage.tar.gz
tar -xzf homepage.tar.gz
rm -rf "$APP_DIR"/* 2>/dev/null || true
cp -r "homepage-${LATEST_VERSION}"/* "$APP_DIR/"
rm -rf "homepage-${LATEST_VERSION}" homepage.tar.gz
chown -R "$APP_USER:$APP_USER" "$APP_DIR"

# Build as user
cd "$APP_DIR"
sudo -u "$APP_USER" bash -c "
export HOME=/home/$APP_USER
export PNPM_HOME=/home/$APP_USER/.local/share/pnpm
export PATH=\$PNPM_HOME:\$PATH
export NEXT_PUBLIC_VERSION='v$LATEST_VERSION'
export NEXT_PUBLIC_REVISION='source'
export NEXT_PUBLIC_BUILDTIME=\$(curl -fsSL https://api.github.com/repos/gethomepage/homepage/releases/latest | jq -r '.published_at')
export NEXT_TELEMETRY_DISABLED=1

pnpm install
pnpm update --no-save caniuse-lite
pnpm build
"

# Configuration
LOCAL_IP=$(hostname -I | awk '{print $1}')
cat > "$APP_DIR/.env" << EOF
HOMEPAGE_ALLOWED_HOSTS=localhost:3000,${LOCAL_IP}:3000,0.0.0.0:3000
HOSTNAME=0.0.0.0
PORT=3000
EOF
chown "$APP_USER:$APP_USER" "$APP_DIR/.env"

# Create/update systemd service
SERVICE_CONTENT="[Unit]
Description=Homepage Dashboard
After=network.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/pnpm start
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=NEXT_TELEMETRY_DISABLED=1
Environment=HOSTNAME=0.0.0.0
Environment=PORT=3000
Environment=HOME=/home/$APP_USER
Environment=PNPM_HOME=/home/$APP_USER/.local/share/pnpm
Environment=PATH=/home/$APP_USER/.local/share/pnpm:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target"

if command -v create_systemd_service >/dev/null 2>&1; then
    create_systemd_service "homepage" "$SERVICE_CONTENT"
else
    echo "$SERVICE_CONTENT" > /etc/systemd/system/homepage.service
    systemctl daemon-reload
    systemctl enable homepage
fi

# Track version and start service
echo "$LATEST_VERSION" > "$VERSION_FILE"

if command -v ensure_service_running >/dev/null 2>&1; then
    ensure_service_running "homepage"
else
    systemctl start homepage
fi

# Wait and show status
sleep 5
echo "Homepage Dashboard installed successfully!"
echo "Access URL: http://$(hostname -I | awk '{print $1}'):3000"
systemctl status homepage --no-pager --lines=10