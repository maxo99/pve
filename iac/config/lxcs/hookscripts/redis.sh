#!/bin/bash
# Redis setup script for LXC container

set -e

# Source helper functions (available via init template)
source /tmp/lxc-helpers.sh 2>/dev/null || true

echo "Starting Redis configuration..."

REDIS_CONF="/etc/redis/redis.conf"
BACKUP_CONF="/etc/redis/redis.conf.backup"

# Create backup of original config if not exists
if [ ! -f "$BACKUP_CONF" ]; then
    cp "$REDIS_CONF" "$BACKUP_CONF"
fi

# Configure Redis to bind to all interfaces (idempotent)
if grep -q "^bind 127.0.0.1" "$REDIS_CONF" || grep -q "^# bind 127.0.0.1" "$REDIS_CONF"; then
    echo "Configuring Redis to bind to all interfaces..."
    # Handle both commented and uncommented bind lines
    sed -i 's/^bind 127.0.0.1.*$/bind 0.0.0.0/' "$REDIS_CONF"
    sed -i 's/^# bind 127.0.0.1.*$/bind 0.0.0.0/' "$REDIS_CONF"
    RESTART_NEEDED=true
else
    echo "Redis already configured to bind to all interfaces"
fi

# Set Redis password (idempotent)
if ! grep -q "^requirepass" "$REDIS_CONF"; then
    echo "Setting Redis password..."
    # Replace placeholder with actual password if provided
    PASSWORD="PASSWORD_PLACEHOLDER"
    # Find and replace the commented requirepass line
    if grep -q "^# requirepass foobared" "$REDIS_CONF"; then
        sed -i "s/^# requirepass foobared$/requirepass $PASSWORD/" "$REDIS_CONF"
    else
        # Fallback: add requirepass line if not found
        echo "requirepass $PASSWORD" >> "$REDIS_CONF"
    fi
    RESTART_NEEDED=true
else
    echo "Redis password already configured"
fi

# Start and enable Redis
if command -v ensure_service_running >/dev/null 2>&1; then
    if [ "${RESTART_NEEDED:-false}" = "true" ]; then
        systemctl restart redis-server
    fi
    ensure_service_running "redis-server"
else
    systemctl enable redis-server
    if [ "${RESTART_NEEDED:-false}" = "true" ] || ! systemctl is-active --quiet redis-server; then
        systemctl restart redis-server
    else
        systemctl start redis-server
    fi
fi

# Test Redis connection
echo "Testing Redis connection..."
sleep 2

# Get the configured password for testing
CONFIGURED_PASSWORD=$(grep "^requirepass" "$REDIS_CONF" | cut -d' ' -f2)
if [ -n "$CONFIGURED_PASSWORD" ]; then
    if redis-cli -a "$CONFIGURED_PASSWORD" ping >/dev/null 2>&1; then
        echo "Redis connection test successful"
    else
        echo "Warning: Redis connection test failed"
    fi
else
    echo "Warning: No password configured for Redis"
fi

LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "Redis Cache Server installed and configured successfully!"
echo "Connection details:"
echo "  Host: $LOCAL_IP"
echo "  Port: 6379"
if [ -n "$CONFIGURED_PASSWORD" ]; then
    echo "  Auth: Password required"
    echo "  Test command: redis-cli -h $LOCAL_IP -a 'PASSWORD_PLACEHOLDER'"
else
    echo "  Auth: No password"
fi
echo ""
systemctl status redis-server --no-pager --lines=5
