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

# Setup Node.js and package managers
echo "Setting up Node.js and package managers..."
setup_nodejs "$NODE_MAJOR"
npm install -g yarn@latest

# Setup Rust for monolith
setup_rust "monolith"

# Setup directories
ensure_directory "$APP_DIR" "root:root" "755"

# Generate database credentials
DB_PASS="$(openssl rand -base64 18 | tr -d '/' | cut -c1-13)"
SECRET_KEY="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)"

# Create database on external PostgreSQL
echo "Setting up database on external PostgreSQL..."
create_postgresql_db "$PG_HOST" "$DB_NAME" "$DB_USER" "$DB_PASS" "$PG_PORT" "$PG_ADMIN_USER" "$PG_ADMIN_PASS"

# Verify database connection before proceeding
echo "Verifying database connection..."
if PGPASSWORD="$DB_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
    echo "Database connection successful"
else
    echo "ERROR: Cannot connect to database with linkwarden credentials"
    echo "Testing with admin credentials..."
    if PGPASSWORD="$PG_ADMIN_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
        echo "Admin connection works - recreating user..."
        PGPASSWORD="$PG_ADMIN_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" -d postgres -c "DROP ROLE IF EXISTS $DB_USER;"
        PGPASSWORD="$PG_ADMIN_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" -d postgres -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';"
        PGPASSWORD="$PG_ADMIN_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
    else
        echo "ERROR: Admin connection also failed"
        exit 1
    fi
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
export NODE_OPTIONS="--max-old-space-size=3072"
export NEXT_TELEMETRY_DISABLED=1
yarn prisma:generate
yarn web:build
yarn prisma:deploy

# Create/update systemd service
create_systemd_service "linkwarden" "[Unit]
Description=Linkwarden Bookmark Manager
After=network.target

[Service]
Type=exec
Environment=PATH=/usr/local/bin:/usr/bin:/bin
Environment=NODE_ENV=production
Environment=NODE_OPTIONS=--max-old-space-size=3072
Environment=NEXT_TELEMETRY_DISABLED=1
WorkingDirectory=$APP_DIR
ExecStart=yarn concurrently:start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target"

# Track version and start service
echo "$LATEST_VERSION" > "$VERSION_FILE"
ensure_service_running "linkwarden"

# Cleanup
rm -rf ~/.cargo/registry ~/.cargo/git ~/.cargo/.package-cache ~/.rustup
rm -rf /root/.cache/yarn /root/.npm /root/.cache/npm
rm -rf "$APP_DIR/.next/cache"

# Wait and show status
sleep 5
echo "Linkwarden Bookmark Manager installed successfully!"
echo "Access URL: http://$(hostname -I | awk '{print $1}'):3000"
echo "Credentials stored in: /root/linkwarden.creds"
systemctl status linkwarden --no-pager --lines=10
