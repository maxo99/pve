#!/bin/bash
# PostgreSQL setup script for LXC container

set -e

# Source helper functions (available via init template)
source /tmp/lxc-helpers.sh 2>/dev/null || true

echo "Starting PostgreSQL configuration..."

# Get PostgreSQL version dynamically
PG_VERSION=$(ls /etc/postgresql/ | head -1)
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"
POSTGRES_USER="postgres"

# Start and enable PostgreSQL if not already running
if command -v ensure_service_running >/dev/null 2>&1; then
    ensure_service_running "postgresql"
else
    systemctl enable postgresql
    systemctl start postgresql
fi

# Check if password is already set (idempotent check)
if ! sudo -u postgres psql -c "SELECT 1;" >/dev/null 2>&1; then
    echo "Setting postgres user password..."
    # Replace placeholder with actual password if provided
    if command -v replace_password_placeholder >/dev/null 2>&1; then
        PASSWORD=$(replace_password_placeholder "PASSWORD_PLACEHOLDER" "PASSWORD_PLACEHOLDER")
    else
        PASSWORD="PASSWORD_PLACEHOLDER"
    fi
    sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '$PASSWORD'"
else
    echo "PostgreSQL user already has password set"
fi

# Configure PostgreSQL to accept connections (idempotent)
PG_CONF="$PG_CONFIG_DIR/postgresql.conf"
PG_HBA="$PG_CONFIG_DIR/pg_hba.conf"

# Check if listen_addresses is already configured
if ! grep -q "listen_addresses = '\*'" "$PG_CONF" 2>/dev/null; then
    echo "Configuring PostgreSQL to listen on all addresses..."
    echo "listen_addresses = '*'" >> "$PG_CONF"
    RESTART_NEEDED=true
else
    echo "PostgreSQL already configured to listen on all addresses"
fi

# Check if host authentication is already configured
if ! grep -q "host all all 0.0.0.0/0 md5" "$PG_HBA" 2>/dev/null; then
    echo "Configuring PostgreSQL host authentication..."
    echo "host all all 0.0.0.0/0 md5" >> "$PG_HBA"
    RESTART_NEEDED=true
else
    echo "PostgreSQL host authentication already configured"
fi

# Restart PostgreSQL only if configuration changed
if [ "${RESTART_NEEDED:-false}" = "true" ]; then
    echo "Restarting PostgreSQL to apply configuration changes..."
    systemctl restart postgresql
else
    echo "No PostgreSQL restart needed"
fi

# Create sample database if it doesn't exist (idempotent)
if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw sampledb; then
    echo "Creating sample database..."
    sudo -u postgres createdb sampledb
else
    echo "Sample database already exists"
fi

# Show connection info
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "PostgreSQL setup completed successfully!"
echo "Connection details:"
echo "  Host: $LOCAL_IP"
echo "  Port: 5432"
echo "  User: postgres"
echo "  Sample Database: sampledb"
echo ""
systemctl status postgresql --no-pager --lines=5
