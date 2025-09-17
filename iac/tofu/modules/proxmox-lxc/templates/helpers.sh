#!/bin/bash
# Common helper functions for LXC scripts
# These functions ensure idempotent operations

# Package management helpers
ensure_packages() {
    export DEBIAN_FRONTEND=noninteractive
    local packages=("$@")
    
    # Update once if needed
    if [ ! -f /tmp/apt-updated-$(date +%Y%m%d) ]; then
        apt-get update
        touch /tmp/apt-updated-$(date +%Y%m%d)
    fi
    
    for pkg in "${packages[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            apt-get install -y --no-install-recommends "$pkg"
        fi
    done
}

# Node.js setup helper
setup_nodejs() {
    local node_major="${1:-22}"
    local current_major=0
    
    if command -v node >/dev/null 2>&1; then
        current_major=$(node -v | cut -d. -f1 | tr -d 'v' | cut -c1-2 || echo 0)
    fi
    
    if [ "$current_major" -ne "$node_major" ]; then
        curl -fsSL "https://deb.nodesource.com/setup_${node_major}.x" | bash -
        apt-get update
        apt-get install -y nodejs
    fi
}

# pnpm setup helper
setup_pnpm() {
    local version="${1:-latest}"
    if ! command -v pnpm >/dev/null 2>&1; then
        npm install -g "pnpm@${version}"
    fi
}

# User creation helper
ensure_user() {
    local username="$1"
    local home_dir="${2:-/home/$username}"
    local shell="${3:-/bin/bash}"
    local system_user="${4:-false}"
    
    if ! id "$username" &>/dev/null; then
        if [ "$system_user" = "true" ]; then
            useradd -r -m -d "$home_dir" -s "$shell" "$username"
        else
            useradd -m -d "$home_dir" -s "$shell" "$username"
        fi
    fi
}

# Systemd service helper
create_systemd_service() {
    local service_name="$1"
    local service_content="$2"
    local service_file="/etc/systemd/system/${service_name}.service"
    
    echo "$service_content" > "$service_file"
    systemctl daemon-reload
    systemctl enable "$service_name"
}

# Repository setup helper
setup_apt_repo() {
    local repo_name="$1"
    local gpg_url="$2"
    local repo_url="$3"
    local gpg_file="/etc/apt/keyrings/${repo_name}.gpg"
    local list_file="/etc/apt/sources.list.d/${repo_name}.list"
    
    if [ ! -f "$gpg_file" ]; then
        mkdir -p /etc/apt/keyrings
        curl -fsSL "$gpg_url" | gpg --dearmor --yes --output "$gpg_file"
    fi
    
    if [ ! -f "$list_file" ]; then
        echo "$repo_url" > "$list_file"
        apt-get update
    fi
}

# Directory ownership helper
ensure_directory() {
    local dir_path="$1"
    local owner="${2:-root:root}"
    local perms="${3:-755}"
    
    mkdir -p "$dir_path" 2>/dev/null || true
    
    # Try to change ownership, but don't fail on read-only filesystems
    if chown "$owner" "$dir_path" 2>/dev/null; then
        true
    else
        echo "Warning: Could not change ownership of $dir_path (possibly read-only)" >&2
    fi
    
    # Try to change permissions, but don't fail on read-only filesystems  
    if chmod "$perms" "$dir_path" 2>/dev/null; then
        true
    else
        echo "Warning: Could not change permissions of $dir_path (possibly read-only)" >&2
    fi
}

# Service status helper
ensure_service_running() {
    local service_name="$1"
    
    # Check if service unit file exists
    if ! systemctl list-unit-files "${service_name}.service" >/dev/null 2>&1; then
        echo "Warning: Service $service_name not found"
        return 1
    fi
    
    # Enable service (ignore errors for masked services)
    systemctl enable "$service_name" 2>/dev/null || true
    
    # Start service if not active
    if ! systemctl is-active --quiet "$service_name"; then
        systemctl start "$service_name" 2>/dev/null || {
            echo "Warning: Failed to start $service_name"
            return 1
        }
    fi
    
    return 0
}

# GitHub release helper
get_latest_github_release() {
    local repo="$1"
    
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        echo "Warning: jq not found, cannot parse GitHub release info" >&2
        return 1
    fi
    
    local release_info
    if ! release_info=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null); then
        echo "Warning: Failed to fetch release info for $repo" >&2
        return 1
    fi
    
    echo "$release_info" | jq -r '.tag_name' | sed 's/^v//'
}

# File download helper
download_and_extract() {
    local url="$1"
    local dest_dir="$2"
    local temp_file="/tmp/$(basename "$url")"
    
    if ! curl -fsSL "$url" -o "$temp_file"; then
        echo "Warning: Failed to download $url" >&2
        return 1
    fi
    
    # Ensure destination directory exists
    mkdir -p "$dest_dir"
    
    case "$temp_file" in
        *.tar.gz|*.tgz)
            tar -xzf "$temp_file" -C "$dest_dir" --strip-components=1 2>/dev/null || {
                echo "Warning: Failed to extract $temp_file" >&2
                rm -f "$temp_file"
                return 1
            }
            ;;
        *.tar.bz2)
            tar -xjf "$temp_file" -C "$dest_dir" --strip-components=1 2>/dev/null || {
                echo "Warning: Failed to extract $temp_file" >&2
                rm -f "$temp_file"
                return 1
            }
            ;;
        *.zip)
            unzip -q "$temp_file" -d "$dest_dir" 2>/dev/null || {
                echo "Warning: Failed to extract $temp_file" >&2
                rm -f "$temp_file"
                return 1
            }
            ;;
        *)
            echo "Warning: Unknown archive format for $temp_file" >&2
            rm -f "$temp_file"
            return 1
            ;;
    esac
    
    rm -f "$temp_file"
    return 0
}

# Container IP helper
get_container_ip() {
    hostname -I | awk '{print $1}'
}

# Version tracking helper
track_version() {
    local app_name="$1"
    local version="$2"
    local version_file="/opt/${app_name}_version.txt"
    
    echo "$version" > "$version_file"
}

# Check if version has changed
version_changed() {
    local app_name="$1"
    local new_version="$2"
    local version_file="/opt/${app_name}_version.txt"
    
    if [ ! -f "$version_file" ]; then
        return 0  # No version file means first install
    fi
    
    local current_version=$(cat "$version_file" 2>/dev/null || echo "")
    [ "$current_version" != "$new_version" ]
}

# Check if package is installed
package_installed() {
    local package="$1"
    dpkg -s "$package" >/dev/null 2>&1
}

# Check if multiple packages are installed
packages_installed() {
    local packages=("$@")
    for pkg in "${packages[@]}"; do
        if ! package_installed "$pkg"; then
            return 1
        fi
    done
    return 0
}

# Conditional package installation
install_if_missing() {
    local packages=("$@")
    local missing_packages=()
    
    for pkg in "${packages[@]}"; do
        if ! package_installed "$pkg"; then
            missing_packages+=("$pkg")
        fi
    done
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        ensure_packages "${missing_packages[@]}"
    fi
}
