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

# Wait for container to be fully started
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

# Ensure host-side mount point directories exist and have appropriate permissions
%{ for mount_point in mount_points ~}
echo "Ensuring host directory exists: ${mount_point.host_path}"
mkdir -p "${mount_point.host_path}"

# Set appropriate permissions on host side for mount points
%{ if can(regex("/(shared|personal)", mount_point.container_path)) ~}
# For shared/personal storage, allow broader access
chown -R root:disk "${mount_point.host_path}" 2>/dev/null || echo "Warning: Could not change ownership of ${mount_point.host_path}"
chmod -R 755 "${mount_point.host_path}" 2>/dev/null || echo "Warning: Could not change permissions of ${mount_point.host_path}"
%{ else ~}
# For other mount points, use more restrictive permissions  
chown -R root:root "${mount_point.host_path}" 2>/dev/null || echo "Warning: Could not change ownership of ${mount_point.host_path}"
chmod -R 755 "${mount_point.host_path}" 2>/dev/null || echo "Warning: Could not change permissions of ${mount_point.host_path}"
%{ endif ~}
%{ endfor ~}

echo "Host-side mount point preparation completed"



# Update the system and install base packages inside container
lxc_exec apt-get update -y
lxc_exec apt-get upgrade -y

# Install required packages inside container
lxc_exec apt-get install -y openssh-server sudo ${packages}


# Create the ${default_user} user if it does not already exist inside container
if ! lxc_exec id ${default_user} &>/dev/null; then
  lxc_exec useradd -m -s /bin/bash ${default_user}
  write_to_container "/etc/sudoers.d/${default_user}" "${default_user} ALL=(ALL) NOPASSWD:ALL"
  # Ensure the file exists inside the container before setting perms
  if ! lxc_exec test -f /etc/sudoers.d/${default_user}; then
      echo "ERROR: sudoers file was not created inside container" >&2
      exit 1
  fi
  lxc_exec chmod 440 /etc/sudoers.d/${default_user}
  
  # Configure SSH for the user inside container
  lxc_exec mkdir -p /home/${default_user}/.ssh
  write_to_container "/home/${default_user}/.ssh/authorized_keys" "${ssh_pub_key}"
  # Ensure authorized_keys exists before adjusting perms/ownership
  if ! lxc_exec test -f /home/${default_user}/.ssh/authorized_keys; then
      echo "ERROR: authorized_keys was not created inside container" >&2
      exit 1
  fi
  lxc_exec chmod 700 /home/${default_user}/.ssh
  lxc_exec chmod 600 /home/${default_user}/.ssh/authorized_keys
  lxc_exec chown -R ${default_user}:${default_user} /home/${default_user}/.ssh
fi

# Create and configure mount point directories
%{ for mount_point in mount_points ~}
echo "Creating mount point directory: ${mount_point.container_path}"
lxc_exec mkdir -p "${mount_point.container_path}"
%{ endfor ~}
%{ if length(mount_points) > 0 ~}
echo "Mount point directories created (permissions inherited from host)"
%{ endif ~}



# Run custom scripts inside container
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
%{ else ~}
lxc_exec bash -c '${script_content}'
%{ endif ~}
%{ endfor ~}



# Ensure SSH service is enabled and running inside container
lxc_exec systemctl enable ssh
lxc_exec systemctl start ssh
echo "LXC container initialization completed successfully for ${hostname} (ID: $VMID)"
echo "Success" > /tmp/lxc-$VMID-init.log
exit 0