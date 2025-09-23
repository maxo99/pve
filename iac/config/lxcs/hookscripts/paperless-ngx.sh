#!/bin/bash
set -e

# Source helper functions (available via init template)
source /tmp/lxc-helpers.sh 2>/dev/null || true

APP="Paperless-ngx"
APP_DIR="/opt/paperless"
VERSION_FILE="/opt/paperless_version.txt"

# External database configuration
POSTGRES_HOST="192.168.6.201"
REDIS_HOST="192.168.6.202"
REDIS_PASSWORD="PASSWORD_PLACEHOLDER"
DB_NAME="paperlessdb"
DB_USER="paperless"

echo "Starting $APP configuration..."

# Check if already installed and up to date
CURRENT_VERSION=""
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
fi

echo "Current $APP version: ${CURRENT_VERSION:-none}"

# Get latest version
LATEST_VERSION=""
if command -v get_latest_github_release >/dev/null 2>&1; then
    LATEST_VERSION=$(get_latest_github_release "paperless-ngx/paperless-ngx" || echo "")
fi

# Fallback if helper function fails
if [ -z "$LATEST_VERSION" ]; then
    LATEST_VERSION=$(curl -fsSL https://api.github.com/repos/paperless-ngx/paperless-ngx/releases/latest | jq -r '.tag_name' | sed 's/^v//')
fi

if [ -z "$LATEST_VERSION" ]; then
    echo "ERROR: Could not determine latest Paperless-ngx version"
    exit 1
fi

echo "Latest $APP version: $LATEST_VERSION"

# Skip if already up to date and service is running
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ] && systemctl is-active --quiet paperless-webserver 2>/dev/null; then
    echo "$APP is already up to date and running"
    exit 0
fi

# Install base dependencies including pkg-config and development tools
echo "Installing base dependencies..."
install_if_missing curl wget gnupg ca-certificates jq pkg-config python3-dev libpq-dev libmariadb-dev-compat libmariadb-dev

# Setup application directory
if command -v ensure_directory >/dev/null 2>&1; then
    ensure_directory "$APP_DIR" "root:root" "755"
else
    mkdir -p "$APP_DIR"
fi

echo "Installing $APP v$LATEST_VERSION..."

# Setup Python with uv
PYTHON_VERSION="3.13" setup_uv

# Download and extract Paperless-ngx
DOWNLOAD_URL="https://github.com/paperless-ngx/paperless-ngx/releases/download/v${LATEST_VERSION}/paperless-ngx-v${LATEST_VERSION}.tar.xz"
TEMP_FILE="/tmp/paperless-ngx.tar.xz"

if ! curl -fsSL "$DOWNLOAD_URL" -o "$TEMP_FILE"; then
    echo "ERROR: Failed to download Paperless-ngx from $DOWNLOAD_URL"
    exit 1
fi

# Extract to application directory
cd /tmp
if ! tar -xf "$TEMP_FILE"; then
    echo "ERROR: Failed to extract Paperless-ngx archive"
    rm -f "$TEMP_FILE"
    exit 1
fi

# Copy extracted files to app directory
cp -r paperless-ngx/* "$APP_DIR/"
rm -rf paperless-ngx "$TEMP_FILE"

# Create Python virtual environment and install dependencies
cd "$APP_DIR"
# Install all extras including MySQL/MariaDB support (but we'll use PostgreSQL)
uv sync --all-extras

# Create required directories
mkdir -p {consume,data,media,static}

# Generate database password and secret key
DB_PASS="PASSWORD_PLACEHOLDER"
SECRET_KEY="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)"

# Create configuration file
cat <<EOF > "$APP_DIR/paperless.conf"
# Paperless-ngx Configuration

# Redis Configuration (with authentication)
PAPERLESS_REDIS=redis://:${REDIS_PASSWORD}@${REDIS_HOST}:6379

# Database Configuration  
PAPERLESS_DBHOST=${POSTGRES_HOST}
PAPERLESS_DBPORT=5432
PAPERLESS_DBNAME=${DB_NAME}
PAPERLESS_DBUSER=${DB_USER}
PAPERLESS_DBPASS=${DB_PASS}

# Security
PAPERLESS_SECRET_KEY=${SECRET_KEY}

# Paths
PAPERLESS_CONSUMPTION_DIR=${APP_DIR}/consume
PAPERLESS_DATA_DIR=${APP_DIR}/data
PAPERLESS_MEDIA_ROOT=${APP_DIR}/media
PAPERLESS_STATICDIR=${APP_DIR}/static

# Additional mount points for document storage
PAPERLESS_CONSUMPTION_DIR_SHARED=/mnt/shared/paperless/consume
PAPERLESS_EXPORT_DIR=/mnt/shared/paperless/export

# OCR and Processing
PAPERLESS_OCR_LANGUAGE=eng
PAPERLESS_TIME_ZONE=UTC

# URL Configuration (adjust if using reverse proxy)
PAPERLESS_URL=http://192.168.6.109:8000
EOF

echo "Created Paperless-ngx configuration"

# Create consumption directories on shared storage
ensure_directory "/mnt/shared/paperless/consume" "root:root" "755"
ensure_directory "/mnt/shared/paperless/export" "root:root" "755"

# Wait for external database to be available
echo "Waiting for PostgreSQL database to be available..."
for i in {1..30}; do
    if pg_isready -h "$POSTGRES_HOST" -p 5432 >/dev/null 2>&1; then
        echo "PostgreSQL is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: PostgreSQL not available after 30 attempts"
        exit 1
    fi
    sleep 2
done

# Wait for Redis to be available
echo "Waiting for Redis to be available..."
for i in {1..30}; do
    if redis-cli -h "$REDIS_HOST" -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
        echo "Redis is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: Redis not available after 30 attempts"
        exit 1
    fi
    sleep 2
done

# Create database and user on external PostgreSQL
echo "Setting up database on external PostgreSQL..."
PGPASSWORD="$DB_PASS" createdb -h "$POSTGRES_HOST" -U postgres "$DB_NAME" 2>/dev/null || echo "Database may already exist"
PGPASSWORD="$DB_PASS" psql -h "$POSTGRES_HOST" -U postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" 2>/dev/null || echo "User may already exist"
PGPASSWORD="$DB_PASS" psql -h "$POSTGRES_HOST" -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" 2>/dev/null || true
PGPASSWORD="$DB_PASS" psql -h "$POSTGRES_HOST" -U postgres -c "ALTER USER $DB_USER CREATEDB;" 2>/dev/null || true

# Run database migrations
echo "Running database migrations..."
cd "$APP_DIR/src"
set -a
. "$APP_DIR/paperless.conf"
set +a
uv run -- python manage.py migrate

# Create admin user
echo "Creating admin user..."
cat <<EOF | uv run -- python /opt/paperless/src/manage.py shell
from django.contrib.auth import get_user_model
UserModel = get_user_model()
if not UserModel.objects.filter(username='admin').exists():
    user = UserModel.objects.create_user('admin', password='$DB_PASS')
    user.is_superuser = True
    user.is_staff = True
    user.save()
    print('Admin user created')
else:
    print('Admin user already exists')
EOF

# Install Natural Language Toolkit
echo "Installing Natural Language Toolkit..."
cd "$APP_DIR"
uv run python -m nltk.downloader -d /usr/share/nltk_data snowball_data
uv run python -m nltk.downloader -d /usr/share/nltk_data stopwords
uv run python -m nltk.downloader -d /usr/share/nltk_data punkt_tab || \
uv run python -m nltk.downloader -d /usr/share/nltk_data punkt

# Configure ImageMagick policy for PDF processing
sed -i -e 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' /etc/ImageMagick-6/policy.xml 2>/dev/null || true

# Create systemd services
echo "Creating systemd services..."

cat <<EOF >/etc/systemd/system/paperless-scheduler.service
[Unit]
Description=Paperless Celery beat
Requires=network.target
After=network.target

[Service]
WorkingDirectory=$APP_DIR/src
ExecStart=uv run -- celery --app paperless beat --loglevel INFO
Environment=DJANGO_SETTINGS_MODULE=paperless.settings
EnvironmentFile=$APP_DIR/paperless.conf
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/paperless-task-queue.service
[Unit]
Description=Paperless Celery Workers
Requires=network.target
After=network.target

[Service]
WorkingDirectory=$APP_DIR/src
ExecStart=uv run -- celery --app paperless worker --loglevel INFO
Environment=DJANGO_SETTINGS_MODULE=paperless.settings
EnvironmentFile=$APP_DIR/paperless.conf
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/paperless-consumer.service
[Unit]
Description=Paperless consumer
Requires=network.target
After=network.target

[Service]
WorkingDirectory=$APP_DIR/src
ExecStartPre=/bin/sleep 2
ExecStart=uv run -- python manage.py document_consumer
Environment=DJANGO_SETTINGS_MODULE=paperless.settings
EnvironmentFile=$APP_DIR/paperless.conf
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/paperless-webserver.service
[Unit]
Description=Paperless webserver
After=network.target
Wants=network.target
Requires=network.target

[Service]
WorkingDirectory=$APP_DIR/src
ExecStart=uv run -- granian --interface asgi --ws "paperless.asgi:application"
Environment=GRANIAN_HOST=::
Environment=GRANIAN_PORT=8000
Environment=GRANIAN_WORKERS=1
Environment=DJANGO_SETTINGS_MODULE=paperless.settings
EnvironmentFile=$APP_DIR/paperless.conf
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
systemctl daemon-reload
systemctl enable paperless-webserver paperless-scheduler paperless-task-queue paperless-consumer

# Track version
if command -v track_version >/dev/null 2>&1; then
    track_version "paperless" "$LATEST_VERSION"
else
    echo "$LATEST_VERSION" > "$VERSION_FILE"
fi

# Start services
if command -v ensure_service_running >/dev/null 2>&1; then
    ensure_service_running "paperless-webserver"
    ensure_service_running "paperless-scheduler" 
    ensure_service_running "paperless-task-queue"
    ensure_service_running "paperless-consumer"
else
    systemctl start paperless-webserver paperless-scheduler paperless-task-queue paperless-consumer
fi

# Show access information
LOCAL_IP=$(hostname -I | awk '{print $1}' || echo "192.168.6.109")
echo "$APP installed successfully!"
echo "Access URL: http://${LOCAL_IP}:8000"
echo "Admin credentials: admin / $DB_PASS"
echo "Document consumption:"
echo "  - Local: $APP_DIR/consume"
echo "  - Shared: /mnt/shared/paperless/consume"
echo "Document export: /mnt/shared/paperless/export"

# Show service status
sleep 3
systemctl status paperless-webserver --no-pager --lines=5 || true
