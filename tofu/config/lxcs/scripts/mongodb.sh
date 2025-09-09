# InfluxDB v1.8 installer - assumes gnupg, curl, ca-certificates present
set -e

. /etc/os-release
CODENAME="${VERSION_CODENAME:-$(lsb_release -cs || echo jammy)}"

# Add InfluxDB v1.8 repository key
curl -fsSL https://repos.influxdata.com/influxdata-archive_compat.key | apt-key add -

# Add InfluxDB v1.8 repository
echo "deb https://repos.influxdata.com/ubuntu ${CODENAME} stable" | tee /etc/apt/sources.list.d/influxdb.list

# Update and install InfluxDB v1.8
apt-get update
apt-get install -y --no-install-recommends influxdb

# Enable and start InfluxDB service
systemctl enable influxdb
systemctl start influxdb

# MongoDB v6.0 installer - assumes gnupg, curl, ca-certificates present
set -e
. /etc/os-release
CODENAME="${VERSION_CODENAME:-$(lsb_release -cs || echo jammy)}"

# Add MongoDB v6.0 repository key and source list
if [ ! -f /usr/share/keyrings/mongodb-server-6.0.gpg ]; then
  curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor
fi
if [ ! -f /etc/apt/sources.list.d/mongodb-org-6.0.list ]; then
  echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
fi

# Update and install MongoDB v6.0
apt-get update
apt-get install -y mongodb-org

# Enable and start MongoDB service
systemctl enable mongod
systemctl start mongod

# Configure MongoDB to accept connections from any IP
echo "net:\n  bindIp: 0.0.0.0" >> /etc/mongod.conf

# Restart MongoDB to apply changes
systemctl restart mongod