#!/bin/bash
set -e

# Install Node.js 22 LTS
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Install pnpm package manager
npm install -g pnpm@latest

# Create homepage user with proper home directory
useradd -r -m -d /home/homepage -s /bin/bash homepage || true

# Create homepage directory and set permissions
mkdir -p /opt/homepage
chown -R homepage:homepage /opt/homepage

# Ensure homepage user has a proper home directory structure
mkdir -p /home/homepage/.local/share/pnpm
mkdir -p /home/homepage/.cache
chown -R homepage:homepage /home/homepage

# Get latest homepage release
RELEASE=$(curl -fsSL https://api.github.com/repos/gethomepage/homepage/releases/latest | jq -r '.tag_name' | sed 's/^v//')
echo "Installing Homepage v$RELEASE"

# Download and extract homepage
cd /tmp
curl -fsSL "https://github.com/gethomepage/homepage/archive/refs/tags/v${RELEASE}.tar.gz" -o homepage.tar.gz
tar -xzf homepage.tar.gz
cp -r homepage-${RELEASE}/* /opt/homepage/
rm -rf homepage-${RELEASE} homepage.tar.gz

# Set permissions
chown -R homepage:homepage /opt/homepage

# Install dependencies and build as homepage user
cd /opt/homepage

# Set environment variables for the homepage user
sudo -u homepage bash -c "
export HOME=/home/homepage
export PNPM_HOME=/home/homepage/.local/share/pnpm
export PATH=\$PNPM_HOME:\$PATH
export NEXT_PUBLIC_VERSION='v$RELEASE'
export NEXT_PUBLIC_REVISION='source'
export NEXT_PUBLIC_BUILDTIME=\$(curl -fsSL https://api.github.com/repos/gethomepage/homepage/releases/latest | jq -r '.published_at')
export NEXT_TELEMETRY_DISABLED=1

pnpm install
pnpm update --no-save caniuse-lite
pnpm build
"

# Get container IP for binding
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Create environment file with proper binding
cat > /opt/homepage/.env << EOF
HOMEPAGE_ALLOWED_HOSTS=localhost:3000,${LOCAL_IP}:3000,0.0.0.0:3000
HOSTNAME=0.0.0.0
PORT=3000
EOF

chown homepage:homepage /opt/homepage/.env

# Create systemd service with proper environment
cat > /etc/systemd/system/homepage.service << 'EOF'
[Unit]
Description=Homepage Dashboard
After=network.target

[Service]
Type=simple
User=homepage
Group=homepage
WorkingDirectory=/opt/homepage
ExecStart=/usr/bin/pnpm start
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=NEXT_TELEMETRY_DISABLED=1
Environment=HOSTNAME=0.0.0.0
Environment=PORT=3000
Environment=HOME=/home/homepage
Environment=PNPM_HOME=/home/homepage/.local/share/pnpm
Environment=PATH=/home/homepage/.local/share/pnpm:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
EOF

# Store version info
echo "$RELEASE" > /opt/homepage_version.txt

# Enable and start service
systemctl daemon-reload
systemctl enable homepage
systemctl start homepage

# Wait a moment for service to start
sleep 5

# Show final status
echo "Homepage Dashboard installed successfully!"
echo "Access URL: http://$(hostname -I | awk '{print $1}'):3000"
echo "Container IP: ${LOCAL_IP}"
systemctl status homepage --no-pager --lines=10