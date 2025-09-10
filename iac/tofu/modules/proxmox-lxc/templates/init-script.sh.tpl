#!/bin/bash

# LXC Hook script for container initialization
# This script runs on the Proxmox host and configures the LXC container
set -e

VMID="$1"
PHASE="$2"

# Only run during post-start phase
if [ "$PHASE" != "post-start" ]; then
    exit 0
fi

# Container filesystem path
CT_PATH="/var/lib/lxc/$VMID/rootfs"

# Status tracking setup
STATUS_DIR="/tmp/${run_id}-lxc-$VMID-status"
mkdir -p "$STATUS_DIR"

# Function to log status with timestamp
log_status() {
    local stage="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $stage: $message" | tee -a "$STATUS_DIR/full.log"
    echo "$message" > "$STATUS_DIR/$stage.status"
    echo "$timestamp" > "$STATUS_DIR/$stage.timestamp"
}

# Function to log error and exit
log_error() {
    local stage="$1"
    local error="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR in $stage: $error" | tee -a "$STATUS_DIR/full.log" "$STATUS_DIR/error.log"
    echo "FAILED: $error" > "$STATUS_DIR/$stage.status"
    echo "$timestamp" > "$STATUS_DIR/failed.timestamp"
    touch "$STATUS_DIR/FAILED"
    exit 1
}

# Trap errors and log them
trap 'log_error "UNKNOWN" "Script failed unexpectedly at line $LINENO"' ERR

# Initialize status tracking
log_status "INIT" "Hook script started for container $VMID"

# Wait for container to be fully started
log_status "WAIT" "Waiting for container to be fully started"
sleep 20

# Function to execute commands inside the container
lxc_exec() {
    lxc-attach -n "$VMID" -- "$@"
}

# Function to write files to container
write_to_container() {
    local file_path="$1"
    local content="$2"
    # Write the file inside the container to avoid host<->container overlay/race issues.
    # Using lxc-attach ensures the container sees the file right away.
    lxc-attach -n "$VMID" -- /bin/bash -c "mkdir -p \"\$(dirname \"$file_path\")\" && cat > \"$file_path\" <<'EOF'
$${content}
EOF"
}

echo "Starting LXC container initialization for ${hostname} (ID: $VMID)"
log_status "MOUNT_PREP" "Starting host-side mount point preparation"

# Ensure host-side mount point directories exist and have appropriate permissions
%{ for mount_point in mount_points ~}
echo "Ensuring host directory exists: ${mount_point.host_path}"
mkdir -p "${mount_point.host_path}" || log_error "MOUNT_PREP" "Failed to create directory ${mount_point.host_path}"

# Set appropriate permissions on host side for mount points
chown -R 100000:100000 "${mount_point.host_path}" 2>/dev/null || echo "Warning: Could not change ownership of ${mount_point.host_path}"
chmod -R 755 "${mount_point.host_path}" 2>/dev/null || echo "Warning: Could not change permissions of ${mount_point.host_path}"
%{ endfor ~}

log_status "MOUNT_PREP" "Host-side mount point preparation completed"



# Update the system and install base packages inside container
log_status "SYSTEM_UPDATE" "Starting system update and package installation"

# Temporarily disable set -e for error handling
set +e
lxc_exec apt-get update -y
if [ $? -ne 0 ]; then
    log_error "SYSTEM_UPDATE" "Failed to update package lists"
fi

lxc_exec apt-get upgrade -y
if [ $? -ne 0 ]; then
    log_error "SYSTEM_UPDATE" "Failed to upgrade system packages"
fi

# Install required packages inside container
lxc_exec apt-get install -y openssh-server sudo ${packages}
if [ $? -ne 0 ]; then
    log_error "SYSTEM_UPDATE" "Failed to install required packages"
fi

# Re-enable set -e
set -e
log_status "SYSTEM_UPDATE" "System update and package installation completed"


# Create the ${default_user} user if it does not already exist inside container
log_status "USER_CONFIG" "Starting user configuration"

# Temporarily disable set -e for error handling
set +e

if ! lxc_exec id ${default_user} &>/dev/null; then
  lxc_exec useradd -m -s /bin/bash ${default_user}
  if [ $? -ne 0 ]; then
      log_error "USER_CONFIG" "Failed to create user ${default_user}"
  fi
  
  write_to_container "/etc/sudoers.d/${default_user}" "${default_user} ALL=(ALL) NOPASSWD:ALL"
  
  # Ensure the file exists inside the container before setting perms
  if ! lxc_exec test -f /etc/sudoers.d/${default_user}; then
      log_error "USER_CONFIG" "sudoers file was not created inside container"
  fi
  
  lxc_exec chmod 440 /etc/sudoers.d/${default_user}
  if [ $? -ne 0 ]; then
      log_error "USER_CONFIG" "Failed to set permissions on sudoers file"
  fi
  
  # Configure SSH for the user inside container
  lxc_exec mkdir -p /home/${default_user}/.ssh
  if [ $? -ne 0 ]; then
      log_error "USER_CONFIG" "Failed to create .ssh directory"
  fi
  
  write_to_container "/home/${default_user}/.ssh/authorized_keys" "${ssh_pub_key}"
  
  # Ensure authorized_keys exists before adjusting perms/ownership
  if ! lxc_exec test -f /home/${default_user}/.ssh/authorized_keys; then
      log_error "USER_CONFIG" "authorized_keys was not created inside container"
  fi
  
  lxc_exec chmod 700 /home/${default_user}/.ssh
  if [ $? -ne 0 ]; then
      log_error "USER_CONFIG" "Failed to set .ssh directory permissions"
  fi
  
  lxc_exec chmod 600 /home/${default_user}/.ssh/authorized_keys
  if [ $? -ne 0 ]; then
      log_error "USER_CONFIG" "Failed to set authorized_keys permissions"
  fi
  
  lxc_exec chown -R ${default_user}:${default_user} /home/${default_user}/.ssh
  if [ $? -ne 0 ]; then
      log_error "USER_CONFIG" "Failed to set .ssh directory ownership"
  fi
fi

# Re-enable set -e
set -e
log_status "USER_CONFIG" "User configuration completed"

# Create and configure mount point directories
log_status "MOUNT_CONFIG" "Starting container mount point configuration"

# Temporarily disable set -e for error handling
set +e

%{ for mount_point in mount_points ~}
echo "Creating mount point directory: ${mount_point.container_path}"
lxc_exec mkdir -p "${mount_point.container_path}"
if [ $? -ne 0 ]; then
    log_error "MOUNT_CONFIG" "Failed to create mount point ${mount_point.container_path}"
fi
%{ endfor ~}

# Re-enable set -e
set -e

%{ if length(mount_points) > 0 ~}
log_status "MOUNT_CONFIG" "Mount point directories created (permissions inherited from host)"
%{ else ~}
log_status "MOUNT_CONFIG" "No mount points to configure"
%{ endif ~}



# Run custom scripts inside container
%{ if length(custom_script_contents) > 0 ~}
log_status "CUSTOM_SCRIPTS" "Starting custom script execution"

# Temporarily disable set -e for error handling
set +e

%{ for script_content in custom_script_contents ~}
echo "Running custom script inside container..."
# Replace password placeholders with actual password if applicable
%{ if generated_password != "" ~}
script_with_password=$(cat <<'SCRIPT_EOF'
${script_content}
SCRIPT_EOF
)
script_with_password=$(echo "$script_with_password" | sed 's/PASSWORD_PLACEHOLDER/${generated_password}/g')
lxc_exec bash -c "$script_with_password"
if [ $? -ne 0 ]; then
    log_error "CUSTOM_SCRIPTS" "Custom script execution failed"
fi
%{ else ~}
lxc_exec bash -c '${script_content}'
if [ $? -ne 0 ]; then
    log_error "CUSTOM_SCRIPTS" "Custom script execution failed"
fi
%{ endif ~}
%{ endfor ~}

# Re-enable set -e
set -e
log_status "CUSTOM_SCRIPTS" "Custom script execution completed"
%{ else ~}
log_status "CUSTOM_SCRIPTS" "No custom scripts to execute"
%{ endif ~}



# Ensure SSH service is enabled and running inside container
log_status "SSH_CONFIG" "Configuring SSH service"

# Temporarily disable set -e for error handling
set +e

lxc_exec systemctl enable ssh
if [ $? -ne 0 ]; then
    log_error "SSH_CONFIG" "Failed to enable SSH service"
fi

lxc_exec systemctl start ssh
if [ $? -ne 0 ]; then
    log_error "SSH_CONFIG" "Failed to start SSH service"
fi

# Re-enable set -e
set -e
log_status "SSH_CONFIG" "SSH service configured and started"

# Final success status
log_status "COMPLETED" "LXC container initialization completed successfully for ${hostname} (ID: $VMID)"
echo "LXC container initialization completed successfully for ${hostname} (ID: $VMID)"

# Create legacy success file for backwards compatibility
echo "Success" > /tmp/${run_id}-lxc-$VMID-init.log

# Create final success marker
touch "$STATUS_DIR/SUCCESS"
echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$STATUS_DIR/completed.timestamp"


jobs -p | xargs -r kill 2>/dev/null || true

sync


exit 0