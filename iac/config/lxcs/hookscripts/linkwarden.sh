#!/bin/bash
set -e

# Source helper functions (available via init template)
source /tmp/lxc-helpers.sh 2>/dev/null || true

# Linkwarden Bookmark Manager installer/updater
APP="Linkwarden"
APP_DIR="/opt/linkwarden"
NODE_MAJOR=22

# PostgreSQL connection details (external container)
PG_HOST="192.168.6.201"
PG_PORT="5432"
DB_NAME="linkwardendb"
DB_USER="linkwarden"
# PostgreSQL admin credentials (use placeholder for replacement)
PG_ADMIN_USER="postgres"
PG_ADMIN_PASS="PASSWORD_PLACEHOLDER"

# Check if already installed and get version
VERSION_FILE="/opt/linkwarden_version.txt"
CURRENT_VERSION=""
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
fi

# Get latest version
if command -v get_latest_github_release >/dev/null 2>&1; then
    LATEST_VERSION=$(get_latest_github_release "linkwarden/linkwarden")
else
    LATEST_VERSION=$(curl -fsSL https://api.github.com/repos/linkwarden/linkwarden/releases/latest | jq -r '.tag_name' | sed 's/^v//')
fi

echo "Current version: ${CURRENT_VERSION:-none}"
echo "Latest version: $LATEST_VERSION"

# Skip if already up to date
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ] && systemctl is-active --quiet linkwarden 2>/dev/null; then
    echo "Linkwarden is already up to date and running"
    exit 0
fi

# Setup Node.js and Yarn
if command -v setup_nodejs >/dev/null 2>&1; then
    setup_nodejs "$NODE_MAJOR"
    setup_pnpm "latest"
else
    # Fallback to manual setup
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -
    apt-get install -y nodejs
    npm install -g yarn@latest
fi

# Setup Rust for monolith
if command -v setup_rust >/dev/null 2>&1; then
    setup_rust "monolith"
else
    # Fallback to manual setup
    echo "Installing Rust (fallback method)..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    
    # Directly add cargo to PATH
    export PATH="/root/.cargo/bin:$PATH"
    
    # Verify cargo is available
    if ! command -v cargo >/dev/null 2>&1; then
        echo "ERROR: cargo command not found"
        echo "Checking cargo binary directly:"
        ls -la "/root/.cargo/bin/cargo" 2>/dev/null || echo "cargo binary not found"
        exit 1
    fi
    
    # Install monolith
    echo "Installing monolith crate..."
    cargo install monolith
fi

# Setup directories
if command -v ensure_directory >/dev/null 2>&1; then
    ensure_directory "$APP_DIR" "root:root" "755"
else
    mkdir -p "$APP_DIR"
fi

# Generate database credentials
DB_PASS="$(openssl rand -base64 18 | tr -d '/' | cut -c1-13)"
SECRET_KEY="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)"

# Create database on external PostgreSQL
echo "Setting up database on external PostgreSQL..."
if command -v create_postgresql_db >/dev/null 2>&1; then
    create_postgresql_db "$PG_HOST" "$DB_NAME" "$DB_USER" "$DB_PASS" "$PG_PORT" "$PG_ADMIN_USER" "$PG_ADMIN_PASS"
else
    # Fallback: Direct connection with proper credentials
    echo "Creating database and user on PostgreSQL container..."
    
    # Test connection first
    if ! PGPASSWORD="$PG_ADMIN_PASS" psql -h "$PG_HOST" -U "$PG_ADMIN_USER" -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
        echo "ERROR: Cannot connect to PostgreSQL at $PG_HOST with user $PG_ADMIN_USER"
        echo "Please verify PostgreSQL container is running and password is correct"
        exit 1
    fi
    
    # Create database user and database
    echo "Creating database user '$DB_USER'..."
    PGPASSWORD="$PG_ADMIN_PASS" psql -h "$PG_HOST" -U "$PG_ADMIN_USER" -d postgres -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';" || echo "User may already exist"
    
    echo "Creating database '$DB_NAME'..."
    PGPASSWORD="$PG_ADMIN_PASS" psql -h "$PG_HOST" -U "$PG_ADMIN_USER" -d postgres -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER ENCODING 'UTF8' TEMPLATE template0;" || echo "Database may already exist"
    
    echo "Setting database permissions..."
    PGPASSWORD="$PG_ADMIN_PASS" psql -h "$PG_HOST" -U "$PG_ADMIN_USER" -d postgres -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';"
    PGPASSWORD="$PG_ADMIN_PASS" psql -h "$PG_HOST" -U "$PG_ADMIN_USER" -d postgres -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';"
    PGPASSWORD="$PG_ADMIN_PASS" psql -h "$PG_HOST" -U "$PG_ADMIN_USER" -d postgres -c "ALTER ROLE $DB_USER SET timezone TO 'UTC';"
    
    echo "Database setup completed successfully"
fi

# Store credentials
cat > "/root/linkwarden.creds" << EOF
Linkwarden-Credentials
Linkwarden Database Host: $PG_HOST
Linkwarden Database User: $DB_USER
Linkwarden Database Password: $DB_PASS
Linkwarden Database Name: $DB_NAME
Linkwarden Secret: $SECRET_KEY

PostgreSQL Admin Credentials Used:
PostgreSQL Admin User: $PG_ADMIN_USER
PostgreSQL Admin Host: $PG_HOST
EOF

# Download and install/update
echo "Installing Linkwarden v$LATEST_VERSION"
cd /tmp
curl -fsSL "https://github.com/linkwarden/linkwarden/archive/refs/tags/v${LATEST_VERSION}.tar.gz" -o linkwarden.tar.gz
tar -xzf linkwarden.tar.gz
rm -rf "$APP_DIR"/* 2>/dev/null || true
cp -r "linkwarden-${LATEST_VERSION}"/* "$APP_DIR/"
rm -rf "linkwarden-${LATEST_VERSION}" linkwarden.tar.gz

# Build application
cd "$APP_DIR"
yarn install
npx playwright install-deps
yarn playwright install

# Get local IP for configuration
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Create environment configuration
cat > "$APP_DIR/.env" << EOF
NEXTAUTH_SECRET=${SECRET_KEY}
NEXTAUTH_URL=http://${LOCAL_IP}:3000
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@${PG_HOST}:${PG_PORT}/${DB_NAME}
EOF

# Generate Prisma client and build
yarn prisma:generate
yarn web:build
yarn prisma:deploy

# Create/update systemd service
SERVICE_CONTENT="[Unit]
Description=Linkwarden Bookmark Manager
After=network.target

[Service]
Type=exec
Environment=PATH=/usr/local/bin:/usr/bin:/bin
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/yarn concurrently:start
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target"

if command -v create_systemd_service >/dev/null 2>&1; then
    create_systemd_service "linkwarden" "$SERVICE_CONTENT"
else
    echo "$SERVICE_CONTENT" > /etc/systemd/system/linkwarden.service
    systemctl daemon-reload
    systemctl enable linkwarden
fi

# Track version and start service
echo "$LATEST_VERSION" > "$VERSION_FILE"

if command -v ensure_service_running >/dev/null 2>&1; then
    ensure_service_running "linkwarden"
else
    systemctl start linkwarden
fi

# Cleanup
rm -rf ~/.cargo/registry ~/.cargo/git ~/.cargo/.package-cache ~/.rustup
rm -rf /root/.cache/yarn
rm -rf "$APP_DIR/.next/cache"

# Wait and show status
sleep 5
echo "Linkwarden Bookmark Manager installed successfully!"
echo "Access URL: http://$(hostname -I | awk '{print $1}'):3000"
echo "Credentials stored in: /root/linkwarden.creds"
systemctl status linkwarden --no-pager --lines=10
