#!/bin/bash
# Docker and Docker Compose setup script for LXC container
# This script is idempotent and can be run multiple times safely

set -e

# Source helper functions (available via init template)
source /tmp/lxc-helpers.sh 2>/dev/null || true

echo "Starting Docker setup..."

# Function to check if Docker is installed and running
check_docker_status() {
    if command -v docker >/dev/null 2>&1; then
        if systemctl is-active --quiet docker; then
            echo "Docker is installed and running"
            return 0
        else
            echo "Docker is installed but not running"
            return 1
        fi
    else
        echo "Docker is not installed"
        return 2
    fi
}

# Function to check Docker Compose version
check_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        local version=$(docker compose version --short 2>/dev/null || echo "unknown")
        echo "Docker Compose is installed (version: $version)"
        return 0
    else
        echo "Docker Compose is not available"
        return 1
    fi
}

# Function to install Docker
install_docker() {
    echo "Installing Docker..."
    
    # Remove any old Docker packages
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Update package index
    apt-get update
    
    # Install prerequisites
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Set up the stable repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index again
    apt-get update
    
    # Install Docker Engine, containerd, and Docker Compose
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    echo "Docker installation completed"
}

# Function to configure Docker
configure_docker() {
    echo "Configuring Docker..."
    
    # Create docker group if it doesn't exist
    groupadd -f docker
    
    # Add the docker user to the docker group if user exists
    if id "docker" &>/dev/null; then
        usermod -aG docker docker
        echo "Added docker user to docker group"
    fi
    
    # Create Docker daemon configuration
    mkdir -p /etc/docker
    
    # Configure Docker daemon with better defaults for LXC
    cat > /etc/docker/daemon.json << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "live-restore": true,
    "userland-proxy": false,
    "experimental": false
}
EOF
    
    # Enable and start Docker service
    if command -v ensure_service_running >/dev/null 2>&1; then
        ensure_service_running "docker"
    else
        systemctl enable docker
        systemctl start docker
    fi
    
    echo "Docker configuration completed"
}

# Function to create basic Docker Compose project directory
setup_compose_directories() {
    echo "Setting up basic Docker Compose directory..."
    
    # Create basic project directory
    mkdir -p /opt/docker-compose
    
    # Set appropriate permissions
    chown -R docker:docker /opt/docker-compose 2>/dev/null || chown -R root:root /opt/docker-compose
    chmod -R 755 /opt/docker-compose
    
    echo "Docker Compose directory setup completed"
}

setup_mounts() {
    echo "Setting up mount directories..."
    
    # Create standard project directories
    mkdir -p /opt/docker-compose
    mkdir -p /opt/docker-compose/data
    mkdir -p /opt/docker-compose/configs
    mkdir -p /opt/docker-compose/logs
    
    # Create directories on mounted storage if available
    if [ -d "/mnt/shared" ]; then
        mkdir -p /mnt/shared/docker-compose
        mkdir -p /mnt/shared/docker-data
        ln -sf /mnt/shared/docker-compose /opt/docker-compose/shared
        ln -sf /mnt/shared/docker-data /opt/docker-compose/shared-data
        echo "Created shared storage directories"
    fi
    
    if [ -d "/mnt/personal" ]; then
        mkdir -p /mnt/personal/docker-compose
        mkdir -p /mnt/personal/docker-data
        ln -sf /mnt/personal/docker-compose /opt/docker-compose/personal
        ln -sf /mnt/personal/docker-data /opt/docker-compose/personal-data
        echo "Created personal storage directories"
    fi
    
    if [ -d "/mnt/tank" ]; then
        mkdir -p /mnt/tank/docker-compose
        mkdir -p /mnt/tank/docker-data
        ln -sf /mnt/tank/docker-compose /opt/docker-compose/tank
        ln -sf /mnt/tank/docker-data /opt/docker-compose/tank-data
        echo "Created tank storage directories"
    fi
    
}

# # Function to create useful scripts and aliases
# create_helper_scripts() {
#     echo "Creating helper scripts..."
#     
#     # Create a compose wrapper script
#     cat > /usr/local/bin/dc << 'EOF'
# #!/bin/bash
# # Docker Compose wrapper script
# cd /opt/docker-compose
# docker compose "$@"
# EOF
#     chmod +x /usr/local/bin/dc
#     
#     # Create a project management script
#     cat > /usr/local/bin/docker-project << 'EOF'
# #!/bin/bash
# # Docker project management script
# 
# COMPOSE_DIR="/opt/docker-compose"
# 
# case "$1" in
#     "list"|"ls")
#         echo "Available Docker Compose projects:"
#         find "$COMPOSE_DIR" -name "docker-compose.yml" -o -name "compose.yml" | while read -r file; do
#             project_dir=$(dirname "$file")
#             project_name=$(basename "$project_dir")
#             echo "  - $project_name ($project_dir)"
#         done
#         ;;
#     "logs")
#         if [ -z "$2" ]; then
#             echo "Usage: docker-project logs <project-name>"
#             exit 1
#         fi
#         project_dir="$COMPOSE_DIR/$2"
#         if [ -d "$project_dir" ]; then
#             cd "$project_dir" && docker compose logs -f
#         else
#             echo "Project '$2' not found"
#             exit 1
#         fi
#         ;;
#     "status")
#         if [ -z "$2" ]; then
#             echo "Usage: docker-project status <project-name>"
#             exit 1
#         fi
#         project_dir="$COMPOSE_DIR/$2"
#         if [ -d "$project_dir" ]; then
#             cd "$project_dir" && docker compose ps
#         else
#             echo "Project '$2' not found"
#             exit 1
#         fi
#         ;;
#     "up")
#         if [ -z "$2" ]; then
#             echo "Usage: docker-project up <project-name> [additional-args]"
#             exit 1
#         fi
#         project_dir="$COMPOSE_DIR/$2"
#         if [ -d "$project_dir" ]; then
#             cd "$project_dir" && docker compose up -d "${@:3}"
#         else
#             echo "Project '$2' not found"
#             exit 1
#         fi
#         ;;
#     "down")
#         if [ -z "$2" ]; then
#             echo "Usage: docker-project down <project-name>"
#             exit 1
#         fi
#         project_dir="$COMPOSE_DIR/$2"
#         if [ -d "$project_dir" ]; then
#             cd "$project_dir" && docker compose down
#         else
#             echo "Project '$2' not found"
#             exit 1
#         fi
#         ;;
#     *)
#         echo "Docker Project Management"
#         echo "Usage: docker-project <command> [args]"
#         echo ""
#         echo "Commands:"
#         echo "  list, ls           List all available projects"
#         echo "  logs <project>     Show logs for a project"
#         echo "  status <project>   Show status of project containers"
#         echo "  up <project>       Start a project"
#         echo "  down <project>     Stop a project"
#         echo ""
#         echo "Project directory: $COMPOSE_DIR"
#         ;;
# esac
# EOF
#     chmod +x /usr/local/bin/docker-project
#     
#     echo "Helper scripts created"
# }

# Function to test Docker installation
test_docker() {
    echo "Testing Docker installation..."
    
    # Test Docker daemon
    if ! docker info >/dev/null 2>&1; then
        echo "Error: Docker daemon is not responding"
        return 1
    fi
    
    # Test Docker Compose
    if ! docker compose version >/dev/null 2>&1; then
        echo "Error: Docker Compose is not working"
        return 1
    fi
    
    # Run a simple test container
    if docker run --rm hello-world >/dev/null 2>&1; then
        echo "Docker test container ran successfully"
    else
        echo "Warning: Docker test container failed"
    fi
    
    echo "Docker installation test completed"
    return 0
}

# Main execution flow
echo "=== Docker Setup Status Check ==="

# Check current Docker status
docker_status=0
check_docker_status || docker_status=$?

compose_status=0
check_docker_compose || compose_status=$?

# Install Docker if needed
if [ $docker_status -eq 2 ]; then
    echo "=== Installing Docker ==="
    install_docker
    configure_docker
elif [ $docker_status -eq 1 ]; then
    echo "=== Starting Docker Service ==="
    if command -v ensure_service_running >/dev/null 2>&1; then
        ensure_service_running "docker"
    else
        systemctl start docker
    fi
    configure_docker
else
    echo "=== Docker Already Installed, Checking Configuration ==="
    # Ensure Docker is properly configured
    if [ ! -f /etc/docker/daemon.json ]; then
        configure_docker
    fi
    # Ensure Docker is enabled and running
    if command -v ensure_service_running >/dev/null 2>&1; then
        ensure_service_running "docker"
    else
        systemctl enable docker
        if ! systemctl is-active --quiet docker; then
            systemctl start docker
        fi
    fi
fi

# Setup directories (always run to ensure consistency)
echo "=== Setting Up Basic Project Structure ==="
setup_compose_directories
setup_mounts
# create_helper_scripts

# Final verification
echo "=== Final Verification ==="
if test_docker; then
    echo "=== Docker Setup Completed Successfully ==="
    
    # Display useful information
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo "Docker Compose Container Ready!"
    echo "Container IP: ${LOCAL_IP}"
    echo ""
    echo "Basic usage:"
    echo "  cd /opt/docker-compose/"
    echo "  docker compose up -d"
    echo ""
    echo "Project directory: /opt/docker-compose/"
    echo ""
    
    # Show Docker info
    echo "Docker version: $(docker --version)"
    echo "Docker Compose version: $(docker compose version --short 2>/dev/null || echo 'unknown')"
    echo ""
    echo "Running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No containers running"
    
else
    echo "=== Docker Setup Encountered Issues ==="
    echo "Please check the logs above for details"
    exit 1
fi
