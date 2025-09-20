#!/bin/bash
# PostgreSQL setup script for LXC container

set -e

# Source helper functions (available via init template)
source /tmp/lxc-helpers.sh 2>/dev/null || true

echo "Starting PostgreSQL configuration..."

# Get PostgreSQL version dynamically
PG_VERSION=$(ls /etc/postgresql/ | head -1)
PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"
PG_CONF="$PG_CONFIG_DIR/postgresql.conf"
PG_HBA="$PG_CONFIG_DIR/pg_hba.conf"

# Start and enable PostgreSQL
ensure_service_running "postgresql"

# Configure postgres user password
echo "Setting postgres user password..."
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'PASSWORD_PLACEHOLDER';"

# Create root database user and database
echo "Creating root database user and database..."
sudo -u postgres createuser --superuser root 2>/dev/null || true
sudo -u postgres createdb root 2>/dev/null || true

# Create sample database
echo "Creating sample database..."
sudo -u postgres createdb sampledb 2>/dev/null || true

# Configure PostgreSQL for remote connections
echo "Configuring PostgreSQL for remote access..."
echo "listen_addresses = '*'" >> "$PG_CONF"
echo "host all postgres 0.0.0.0/0 md5" >> "$PG_HBA"
echo "host all all 192.168.0.0/16 md5" >> "$PG_HBA"

# Restart PostgreSQL to apply configuration
echo "Restarting PostgreSQL..."
systemctl restart postgresql

# Show connection info
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "PostgreSQL setup completed successfully!"
echo "Connection details:"
echo "  Host: $LOCAL_IP"
echo "  Port: 5432"
echo "  Database Users:"
echo "    - postgres (password: configured via PASSWORD_PLACEHOLDER)"
echo "    - root (no password, local only)"
echo "  Databases: postgres, root, sampledb"
echo ""
echo "Remote connection test:"
echo "  psql -h $LOCAL_IP -U postgres -d postgres"
echo ""
