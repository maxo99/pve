#!/bin/bash
# PostgreSQL setup script for LXC container

set -e

echo "Starting PostgreSQL configuration..."

# Configure PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Set postgres user password (placeholder will be replaced)
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'PASSWORD_PLACEHOLDER'"

# Configure PostgreSQL to accept connections
echo "listen_addresses = '*'" >> /etc/postgresql/14/main/postgresql.conf
echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/14/main/pg_hba.conf

# Restart PostgreSQL to apply changes
systemctl restart postgresql

# Create a sample database
sudo -u postgres createdb sampledb

echo "PostgreSQL setup completed successfully!"
