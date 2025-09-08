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