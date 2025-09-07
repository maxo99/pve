#!/bin/bash
# Redis setup script for LXC container

set -e

echo "Starting Redis configuration..."

# Configure Redis to bind to all interfaces
sed -i 's/^bind 127.0.0.1 ::1$/bind 0.0.0.0/' /etc/redis/redis.conf

# Set Redis password (placeholder will be replaced)
sed -i 's/^# requirepass foobared$/requirepass PASSWORD_PLACEHOLDER/' /etc/redis/redis.conf

# Enable and restart Redis
systemctl enable redis-server
systemctl restart redis-server

# Test Redis connection
echo "Testing Redis connection..."
sleep 2
redis-cli -a 'PASSWORD_PLACEHOLDER' ping

echo "Redis Cache Server installed and configured successfully!"
echo "Access: redis-cli -h $(hostname -I | awk '{print $1}') -a 'PASSWORD_PLACEHOLDER'"

# Show Redis status
systemctl status redis-server --no-pager
