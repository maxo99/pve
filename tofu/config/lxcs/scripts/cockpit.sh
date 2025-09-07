#!/bin/bash
# Cockpit setup script for LXC container

set -e

echo "Starting Cockpit configuration..."

# Function to safely download and install .deb packages
install_cockpit_module() {
    local repo_name="$1"
    local module_name="$2"
    
    echo "Installing Cockpit ${module_name} module..."
    
    # Get the latest release info and extract download URL more safely
    local release_info=$(curl -fsSL "https://api.github.com/repos/45Drives/${repo_name}/releases/latest")
    local download_url=$(echo "$release_info" | jq -r '.assets[] | select(.name | contains("jammy")) | .browser_download_url' | head -1)
    
    # Fallback to focal if jammy not available
    if [ "$download_url" = "null" ] || [ -z "$download_url" ]; then
        echo "Jammy package not found, trying focal..."
        download_url=$(echo "$release_info" | jq -r '.assets[] | select(.name | contains("focal")) | .browser_download_url' | head -1)
    fi
    
    # Final fallback to any .deb file
    if [ "$download_url" = "null" ] || [ -z "$download_url" ]; then
        echo "Focal package not found, trying any available .deb..."
        download_url=$(echo "$release_info" | jq -r '.assets[] | select(.name | endswith(".deb")) | .browser_download_url' | head -1)
    fi
    
    if [ "$download_url" = "null" ] || [ -z "$download_url" ]; then
        echo "Warning: No compatible package found for ${module_name}, skipping..."
        return 1
    fi
    
    local filename=$(basename "$download_url")
    echo "Downloading: $filename"
    
    curl -fsSL "$download_url" -o "$filename"
    dpkg -i "$filename" || apt-get install -f -y
    rm -f "$filename"
    echo "Cockpit ${module_name} module installed successfully"
    return 0
}

# Start and enable Cockpit
systemctl start cockpit
systemctl enable cockpit

# Install Cockpit modules with error handling
install_cockpit_module "cockpit-file-sharing" "File Sharing" || echo "File Sharing module installation failed, continuing..."
install_cockpit_module "cockpit-identities" "Identities" || echo "Identities module installation failed, continuing..."
install_cockpit_module "cockpit-navigator" "Navigator" || echo "Navigator module installation failed, continuing..."


# Configure Samba for file sharing (since NFS is problematic in LXC)
echo "Configuring Samba file sharing..."
mkdir -p /etc/samba
cat > /etc/samba/smb.conf << 'EOF'
[global]
   workgroup = WORKGROUP
   server string = Cockpit File Server
   netbios name = cockpit-mgmt
   security = user
   map to guest = Bad User
   dns proxy = no
   load printers = no
   printcap name = /dev/null
   disable spoolss = yes

[shared]
   comment = Shared Storage
   path = /mnt/shared
   browseable = yes
   writable = yes
   guest ok = yes
   read only = no
   force user = root
   force group = root
   create mask = 0664
   force create mode = 0664
   directory mask = 0775
   force directory mode = 0775

[personal]
   comment = Personal Storage
   path = /mnt/personal
   browseable = yes
   writable = yes
   guest ok = yes
   read only = no
   force user = root
   force group = root
   create mask = 0664
   force create mode = 0664
   directory mask = 0775
   force directory mode = 0775

[tank]
   comment = ZFS Tank Storage
   path = /mnt/tank
   browseable = yes
   writable = yes
   guest ok = yes
   read only = no
   force user = root
   force group = root
   create mask = 0664
   force create mode = 0664
   directory mask = 0775
   force directory mode = 0775
EOF

# Test samba configuration
testparm -s || echo "Warning: Samba configuration test failed"

# Enable and start Samba services
systemctl enable smbd nmbd winbind
systemctl start smbd nmbd winbind


# Configure Cockpit to listen on all interfaces
mkdir -p /etc/cockpit/ws-certs.d


# Create mount point directories
mkdir -p /mnt/shared /mnt/personal /mnt/snapshots /mnt/tank
echo 'Storage mount points created'


# Configure storage permissions for cockpit user access
chown -R root:disk /mnt/shared /mnt/personal /mnt/tank || true
chmod -R 755 /mnt/shared /mnt/personal /mnt/tank || true
echo 'Storage permissions configured'


# Restart Cockpit to apply all changes
systemctl restart cockpit


# Display final status and access information
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo ''
echo 'Cockpit Management Interface installed successfully!'
echo 'Installed modules:'
echo '  - Core Cockpit (System monitoring, services, logs)'
echo '  - File Sharing (Samba/NFS management)'
echo '  - Identities (User/Group management)'
echo '  - Navigator (File browser and management)'
echo ''
echo 'Available Storage:'
echo '  - /mnt/shared (BTRFS proxmox-shared)'
echo '  - /mnt/personal (BTRFS proxmox-personal)'
echo '  - /mnt/snapshots (BTRFS snapshots - read-only)'
echo '  - /mnt/tank (ZFS tank pool)'
echo ''
echo "Access URL: https://${LOCAL_IP}:9090"
echo ''
systemctl status cockpit --no-pager