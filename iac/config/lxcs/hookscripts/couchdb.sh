#!/bin/bash
# CouchDB setup script for LXC container
# Adapted from community-scripts couchdb-install.sh

set -e

# Source helper functions (available via init template)
source /tmp/lxc-helpers.sh 2>/dev/null || true

echo "Starting CouchDB installation and configuration..."

# Get OS version codename
VERSION_CODENAME="$(awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release)"
echo "Detected OS version: $VERSION_CODENAME"

# Generate Erlang cookie and use default admin password
ERLANG_COOKIE=$(openssl rand -base64 32)
ADMIN_PASS="ADMIN_PASSWORD_PLACEHOLDER"

echo "Setting up CouchDB repository..."
# Add CouchDB GPG key (idempotent)
if [ ! -f /usr/share/keyrings/couchdb-archive-keyring.gpg ]; then
    curl -fsSL https://couchdb.apache.org/repo/keys.asc | gpg --dearmor -o /usr/share/keyrings/couchdb-archive-keyring.gpg
    echo "Added CouchDB GPG key"
else
    echo "CouchDB GPG key already exists"
fi

# Add CouchDB repository (idempotent)
REPO_FILE="/etc/apt/sources.list.d/couchdb.sources.list"
if [ ! -f "$REPO_FILE" ]; then
    echo "deb [signed-by=/usr/share/keyrings/couchdb-archive-keyring.gpg] https://apache.jfrog.io/artifactory/couchdb-deb/ ${VERSION_CODENAME} main" > "$REPO_FILE"
    apt-get update
    echo "Added CouchDB repository"
else
    echo "CouchDB repository already configured"
fi

# Pre-configure CouchDB installation (idempotent)
echo "Pre-configuring CouchDB installation..."
debconf-set-selections <<<"couchdb couchdb/cookie string $ERLANG_COOKIE"
debconf-set-selections <<<"couchdb couchdb/mode select standalone"
debconf-set-selections <<<"couchdb couchdb/bindaddress string 0.0.0.0"
debconf-set-selections <<<"couchdb couchdb/adminpass password $ADMIN_PASS"
debconf-set-selections <<<"couchdb couchdb/adminpass_again password $ADMIN_PASS"

# Install CouchDB if not already installed
if ! dpkg -s couchdb >/dev/null 2>&1; then
    echo "Installing CouchDB..."
    apt-get install -y couchdb
    echo "CouchDB installation completed"
else
    echo "CouchDB already installed"
fi

# Ensure CouchDB service is running
if command -v ensure_service_running >/dev/null 2>&1; then
    ensure_service_running "couchdb"
else
    systemctl enable couchdb
    systemctl start couchdb
fi

# Configure data directory on /tank (idempotent)
echo "Configuring data storage on /tank..."
COUCHDB_DATA_DIR="/mnt/tank/couchdb-data"
COUCHDB_CONFIG="/opt/couchdb/etc/local.ini"

# Create data directory on tank if it doesn't exist
if [ ! -d "$COUCHDB_DATA_DIR" ]; then
    mkdir -p "$COUCHDB_DATA_DIR"
    chown couchdb:couchdb "$COUCHDB_DATA_DIR"
    echo "Created CouchDB data directory on /tank"
else
    echo "CouchDB data directory already exists on /tank"
fi

# Configure CouchDB to use /tank for data storage (idempotent)
if ! grep -q "database_dir.*tank" "$COUCHDB_CONFIG" 2>/dev/null; then
    echo "Configuring CouchDB to use /tank for data storage..."
    
    # Backup original config
    cp "$COUCHDB_CONFIG" "$COUCHDB_CONFIG.backup" 2>/dev/null || true
    
    # Add database directory configuration
    cat >> "$COUCHDB_CONFIG" << EOF

[couchdb]
database_dir = $COUCHDB_DATA_DIR
view_index_dir = $COUCHDB_DATA_DIR

EOF
    
    # Restart CouchDB to apply data directory change
    systemctl restart couchdb
    echo "CouchDB data directory configuration applied"
else
    echo "CouchDB data directory already configured for /tank"
fi

# Store credentials (idempotent)
CREDS_FILE="$HOME/CouchDB.creds"
if [ ! -f "$CREDS_FILE" ]; then
    echo "Storing CouchDB credentials..."
    echo -e "CouchDB Erlang Cookie: \e[32m$ERLANG_COOKIE\e[0m" > "$CREDS_FILE"
    echo -e "CouchDB Admin Password: \e[32m$ADMIN_PASS\e[0m" >> "$CREDS_FILE"
    chmod 600 "$CREDS_FILE"
    echo "Credentials stored in $CREDS_FILE"
else
    echo "Credentials file already exists"
fi

# Test CouchDB connectivity
echo "Testing CouchDB connectivity..."
sleep 3
LOCAL_IP=$(hostname -I | awk '{print $1}')

if curl -s http://localhost:5984/ >/dev/null 2>&1; then
    echo "CouchDB is responding on localhost"
else
    echo "Warning: CouchDB may not be fully started yet"
fi

echo "CouchDB installation and configuration completed successfully!"
echo ""
echo "Connection details:"
echo "  Host: $LOCAL_IP"
echo "  Port: 5984"
echo "  Web UI: http://$LOCAL_IP:5984/_utils/"
echo "  Admin user: admin"
echo "  Admin password: stored in $CREDS_FILE"
echo "  Data location: $COUCHDB_DATA_DIR"
echo ""
echo "Test commands:"
echo "  curl http://$LOCAL_IP:5984/"
echo "  curl -X GET http://admin:$ADMIN_PASS@$LOCAL_IP:5984/_all_dbs"
echo ""

# Clean up
apt-get -y autoremove >/dev/null 2>&1 || true
apt-get -y autoclean >/dev/null 2>&1 || true

systemctl status couchdb --no-pager --lines=5