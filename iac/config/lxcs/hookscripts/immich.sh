#!/bin/bash
# Immich LXC install via Docker Compose using external Postgres & Redis
# Non-interactive, idempotent. Debian 12 base. GPU passthrough enabled by Proxmox config.

set -euo pipefail

# Bring in shared helper functions (provided by the orchestrator)
source /tmp/lxc-helpers.sh 2>/dev/null || true

APP="immich"
APP_DIR="/opt/immich"
CONFIG_DIR="/etc/immich"
COMPOSE_FILE="${APP_DIR}/docker-compose.yml"
MEDIA_DIR_HOST="/tank/immich"

# External services
PG_HOST="192.168.6.201"
PG_PORT="5432"
DB_NAME="immich"
DB_USER="immich"
DB_PASS="P@ssw0rd"

REDIS_HOST="192.168.6.202"
REDIS_PORT="6379"
REDIS_PASS="P@ssw0rd"

# PostgreSQL admin (existing server) for bootstrap
PG_ADMIN_USER="postgres"
PG_ADMIN_PASS="P@ssw0rd"

# Ensure base directories
ensure_directory "$APP_DIR" "root:root" "755"
ensure_directory "$CONFIG_DIR" "root:root" "755"
ensure_directory "$MEDIA_DIR_HOST" "root:root" "755"

# Ensure Immich upload subdirectories and marker files exist
for d in "thumbs" "upload" "backups" "library" "profile" "encoded-video"; do
  ensure_directory "${MEDIA_DIR_HOST}/${d}" "root:root" "775"
  if [ ! -f "${MEDIA_DIR_HOST}/${d}/.immich" ]; then
    touch "${MEDIA_DIR_HOST}/${d}/.immich"
    chmod 664 "${MEDIA_DIR_HOST}/${d}/.immich" || true
  fi
done

# Install Docker Engine + Compose plugin (Debian)
if ! command -v docker >/dev/null 2>&1; then
  ensure_packages ca-certificates curl gnupg lsb-release apt-transport-https
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
fi

# TZ for containers
TZ_VAL="$(cat /etc/timezone 2>/dev/null || echo UTC)"

# Ensure DB and Redis availability, then create DB/user if absent
if ! command -v pg_isready >/dev/null 2>&1; then
  ensure_packages postgresql-client || true
fi
if ! command -v redis-cli >/dev/null 2>&1; then
  ensure_packages redis-tools || true
fi

echo "Waiting for PostgreSQL @ ${PG_HOST}:${PG_PORT}..."
for i in $(seq 1 30); do
  if pg_isready -h "$PG_HOST" -p "$PG_PORT" >/dev/null 2>&1; then
    echo "PostgreSQL is ready"; break
  fi
  sleep 2
  if [ "$i" -eq 30 ]; then echo "ERROR: PostgreSQL not reachable" >&2; fi
done

echo "Waiting for Redis @ ${REDIS_HOST}:${REDIS_PORT}..."
for i in $(seq 1 30); do
  if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASS" ping >/dev/null 2>&1; then
    echo "Redis is ready"; break
  fi
  sleep 2
  if [ "$i" -eq 30 ]; then echo "ERROR: Redis not reachable" >&2; fi
done

# Create database and role (idempotent)
echo "Ensuring database and role exist..."
PGPASSWORD="$PG_ADMIN_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" -d postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 || \
PGPASSWORD="$PG_ADMIN_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" -d postgres -c "CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASS}';"

PGPASSWORD="$PG_ADMIN_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 || \
PGPASSWORD="$PG_ADMIN_PASS" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" -d postgres -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER} ENCODING 'UTF8' TEMPLATE template0;"

# Compose environment - external DB/Redis and hardware accel via VAAPI
ENV_FILE="${APP_DIR}/.env"
cat >"$ENV_FILE" <<ENV
TZ=${TZ_VAL}
# Database
DB_HOSTNAME=${PG_HOST}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}
DB_DATABASE_NAME=${DB_NAME}
DB_PORT=${PG_PORT}
DB_USE_SSL=false
DB_VECTOR_EXTENSION=vectorchord
# Redis
REDIS_HOSTNAME=${REDIS_HOST}
REDIS_PORT=${REDIS_PORT}
REDIS_PASSWORD=${REDIS_PASS}
# Media
IMMICH_MEDIA_LOCATION=/usr/src/app/upload
# ML service endpoint
IMMICH_MACHINE_LEARNING_URL=http://immich-machine-learning:3003
ENV

# Compose file based on Immich docs with external DB/Redis
cat >"$COMPOSE_FILE" <<'YAML'
services:
  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich-server
    restart: unless-stopped
    env_file:
      - ./.env
    environment:
      - NODE_ENV=production
    ports:
      - "2283:2283"
    devices:
      - "/dev/dri:/dev/dri"
    volumes:
      - /etc/immich:/config
      - /tank/immich:/usr/src/app/upload
    depends_on:
      - immich-machine-learning

  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:release
    container_name: immich-machine-learning
    restart: unless-stopped
    env_file:
      - ./.env
    environment:
      - NODE_ENV=production
    volumes:
      - /tank/immich:/cache
YAML

# Systemd unit to manage compose stack
create_systemd_service "immich-compose" "[Unit]
Description=Immich (Docker Compose)
After=network-online.target docker.service
Wants=network-online.target docker.service

[Service]
Type=oneshot
WorkingDirectory=${APP_DIR}
RemainAfterExit=yes
ExecStartPre=-/usr/bin/docker compose pull --quiet
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=300
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target"

# Pull and start
ensure_service_running immich-compose || true

LOCAL_IP=$(get_container_ip)
echo "Immich setup complete. Access: http://${LOCAL_IP}:2283"
