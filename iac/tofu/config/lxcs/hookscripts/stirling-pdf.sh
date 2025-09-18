#!/bin/bash
# Stirling PDF LXC Installation Script
# This script sets up the complete Stirling PDF environment with Java, LibreOffice, and unoserver

set -e

# Source helper functions (available via init template)
source /tmp/lxc-helpers.sh 2>/dev/null || true

echo "Starting Stirling PDF setup..."

# Function to setup Python environment with uv
setup_python_environment() {
    echo "Setting up Python environment..."
    
    # Use helper function to create Python virtual environment
    setup_python_venv "/opt/.venv" "3.12" \
        "opencv-python-headless" \
        "ocrmypdf" \
        "pillow" \
        "pdf2image"
    
    # Ensure uv is in PATH
    export PATH="/usr/local/bin:$PATH"
    export PATH="/opt/.venv/bin:$PATH"
    source /opt/.venv/bin/activate
    
    # Install system Python packages
    ensure_packages python3-uno python3-pip
    pip3 install --break-system-packages unoserver
    
    # Create symlinks for global access
    ln -sf /opt/.venv/bin/python3 /usr/local/bin/python3
    ln -sf /opt/.venv/bin/pip /usr/local/bin/pip
    
    # Ensure unoserver is accessible globally
    if [ -f /usr/local/lib/python3.*/dist-packages/unoserver/server.py ]; then
        # Create a wrapper script for unoserver
        cat > /usr/local/bin/unoserver << 'EOF'
#!/bin/bash
exec python3 -m unoserver.server "$@"
EOF
        chmod +x /usr/local/bin/unoserver
    elif command -v unoserver >/dev/null 2>&1; then
        # If unoserver is already in PATH, create symlink
        UNOSERVER_PATH=$(which unoserver)
        ln -sf "$UNOSERVER_PATH" /usr/local/bin/unoserver
    else
        echo "WARNING: unoserver installation may have issues"
    fi
    
    echo "Python environment setup completed"
}

# Function to install LibreOffice components
install_libreoffice() {
    echo "Installing LibreOffice components..."
    
    local LIBREOFFICE_PACKAGES=(
        libreoffice-writer
        libreoffice-calc
        libreoffice-impress
        libreoffice-core
        libreoffice-common
        libreoffice-base-core
        libreoffice-script-provider-python
        libreoffice-java-common
        unoconv
        pngquant
        weasyprint
    )
    
    # Use helper function to install only missing packages
    install_if_missing "${LIBREOFFICE_PACKAGES[@]}"
    
    echo "LibreOffice installation completed"
}

# Function to install JBIG2 encoder
install_jbig2() {
    echo "Installing JBIG2 encoder..."
    
    if command -v jbig2 >/dev/null 2>&1; then
        echo "JBIG2 already installed"
        return 0
    fi
    
    # Install build dependencies
    ensure_packages build-essential autotools-dev automake libtool
    
    # Use helper function to build from source
    build_from_source \
        "https://github.com/agl/jbig2enc/archive/refs/tags/0.30.tar.gz" \
        "/opt/jbig2enc"
    
    echo "JBIG2 installation completed"
}

# Function to install Tesseract language packs
install_tesseract_languages() {
    echo "Installing Tesseract language packs..."
    
    # Install all available tesseract language packs using helper
    ensure_packages 'tesseract-ocr-*'
    
    echo "Tesseract language packs installation completed"
}

# Function to download and setup Stirling PDF
setup_stirling_pdf() {
    echo "Setting up Stirling PDF..."
    
    # Create Stirling PDF directory
    mkdir -p /opt/Stirling-PDF
    mkdir -p /tmp/stirling-pdf
    
    # Determine if we want login version (default: yes for enhanced security)
    echo "Setting up Stirling PDF with login authentication..."
    
    # Download Stirling PDF with login
    LATEST_RELEASE=$(curl -s https://api.github.com/repos/Stirling-Tools/Stirling-PDF/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4)
    DOWNLOAD_URL="https://github.com/Stirling-Tools/Stirling-PDF/releases/download/${LATEST_RELEASE}/Stirling-PDF-with-login.jar"
    
    echo "Downloading Stirling PDF ${LATEST_RELEASE}..."
    curl -fsSL -o /opt/Stirling-PDF/Stirling-PDF.jar "$DOWNLOAD_URL"
    
    # Mark that login is enabled
    touch ~/.Stirling-PDF-login
    
    echo "Stirling PDF download completed"
}

# Function to create environment configuration
create_environment_config() {
    echo "Creating environment configuration..."
    
    cat <<EOF >/opt/Stirling-PDF/.env
# Java tuning
JAVA_BASE_OPTS="-XX:+UnlockExperimentalVMOptions -XX:MaxRAMPercentage=75 -XX:InitiatingHeapOccupancyPercent=20 -XX:+G1PeriodicGCInvokesConcurrent -XX:G1PeriodicGCInterval=10000 -XX:+UseStringDeduplication -XX:G1PeriodicGCSystemLoadThreshold=70"
JAVA_CUSTOM_OPTS=""

# LibreOffice
PATH=/opt/.venv/bin:/usr/lib/libreoffice/program:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
UNO_PATH=/usr/lib/libreoffice/program
URE_BOOTSTRAP=file:///usr/lib/libreoffice/program/fundamentalrc
PYTHONPATH=/usr/lib/libreoffice/program:/opt/.venv/lib/python3.12/site-packages
LD_LIBRARY_PATH=/usr/lib/libreoffice/program

STIRLING_TEMPFILES_DIRECTORY=/tmp/stirling-pdf
TMPDIR=/tmp/stirling-pdf
TEMP=/tmp/stirling-pdf
TMP=/tmp/stirling-pdf

# Paths
PATH=/opt/.venv/bin:/usr/lib/libreoffice/program:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Activate Login
DISABLE_ADDITIONAL_FEATURES=false
SECURITY_ENABLELOGIN=true

# Login credentials (default: admin/stirling - change after first login)
SECURITY_INITIALLOGIN_USERNAME=admin
SECURITY_INITIALLOGIN_PASSWORD=stirling
EOF
    
    echo "Environment configuration created"
}

# Function to create systemd services
create_services() {
    echo "Creating systemd services..."
    
    # LibreOffice Listener Service
    create_systemd_service "libreoffice-listener" '[Unit]
Description=LibreOffice Headless Listener Service
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/lib/libreoffice/program/soffice --headless --invisible --nodefault --nofirststartwizard --nolockcheck --nologo --accept="socket,host=127.0.0.1,port=2002;urp;StarOffice.ComponentContext"
Restart=always

[Install]
WantedBy=multi-user.target'

    # Stirling PDF Service
    create_systemd_service "stirlingpdf" '[Unit]
Description=Stirling-PDF service
After=syslog.target network.target libreoffice-listener.service
Requires=libreoffice-listener.service

[Service]
SuccessExitStatus=143
Type=simple
User=root
Group=root
EnvironmentFile=/opt/Stirling-PDF/.env
WorkingDirectory=/opt/Stirling-PDF
ExecStart=/usr/bin/java -jar Stirling-PDF.jar
ExecStop=/bin/kill -15 $MAINPID
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target'

    # UnoServer Service
    create_systemd_service "unoserver" '[Unit]
Description=UnoServer RPC Interface
After=libreoffice-listener.service
Requires=libreoffice-listener.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 -m unoserver.server --port 2003 --interface 127.0.0.1
Restart=always
EnvironmentFile=/opt/Stirling-PDF/.env
Environment=PYTHONPATH=/usr/lib/libreoffice/program

[Install]
WantedBy=multi-user.target'
    
    echo "Systemd services created"
}

# Function to start and enable services
start_services() {
    echo "Starting and enabling services..."
    
    # Use helper function to start services
    ensure_service_running "libreoffice-listener"
    ensure_service_running "stirlingpdf"  
    ensure_service_running "unoserver"
    
    echo "Services started and enabled"
}

# Function to refresh font cache
refresh_font_cache() {
    echo "Refreshing font cache..."
    fc-cache -fv
    echo "Font cache refreshed"
}

# Function to cleanup installation files
cleanup_installation() {
    echo "Cleaning up installation files..."
    
    # Use standard cleanup commands
    apt-get -y autoremove
    apt-get -y autoclean
    
    # Remove temporary directories created during installation
    rm -rf /tmp/stirling-pdf-install /opt/jbig2enc
    
    echo "Cleanup completed"
}

# Main installation flow
echo "=== Stirling PDF Installation ==="

# Install core dependencies
echo "Installing core dependencies..."
ensure_packages curl wget gnupg ca-certificates

# Setup Java using helper function
setup_java 21

# Setup Python environment
setup_python_environment

# Install LibreOffice
install_libreoffice

# Install JBIG2
install_jbig2

# Install Tesseract languages
install_tesseract_languages

# Setup Stirling PDF
setup_stirling_pdf

# Create environment configuration
create_environment_config

# Refresh font cache
refresh_font_cache

# Create and start services
create_services
start_services

# Cleanup
cleanup_installation

# Final status
LOCAL_IP=$(get_container_ip)
echo ""
echo "=== Stirling PDF Installation Completed Successfully ==="
echo "Container IP: ${LOCAL_IP}"
echo "Access URL: http://${LOCAL_IP}:8080"
echo ""
echo "Default Login Credentials:"
echo "  Username: admin"
echo "  Password: stirling"
echo "  (Please change these after first login)"
echo ""
echo "Services Status:"
systemctl status libreoffice-listener --no-pager --lines=2
systemctl status stirlingpdf --no-pager --lines=2
systemctl status unoserver --no-pager --lines=2
echo ""
echo "Stirling PDF is ready for PDF processing, editing, and conversion!"
