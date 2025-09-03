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
sleep 5

# Function to execute commands inside the container
lxc_exec() {
    lxc-attach -n "$VMID" -- "$@"
}

# Function to write files to container
write_to_container() {
    local file_path="$1"
    local content="$2"
    # Ensure directory exists
    mkdir -p "$(dirname "$CT_PATH$file_path")"
    echo "$content" > "$CT_PATH$file_path"
}

echo "Starting LXC container initialization for ${hostname} (ID: $VMID)"

# Update the system and install base packages inside container
lxc_exec apt-get update -y
lxc_exec apt-get upgrade -y

# Install required packages inside container
lxc_exec apt-get install -y openssh-server sudo ${packages}

# SSH keys are handled by Proxmox initialization - no manual SSH setup needed

# Create the ${default_user} user if it does not already exist inside container
if ! lxc_exec id ${default_user} &>/dev/null; then
  lxc_exec useradd -m -s /bin/bash ${default_user}
  write_to_container "/etc/sudoers.d/${default_user}" "${default_user} ALL=(ALL) NOPASSWD:ALL"
  lxc_exec chmod 440 /etc/sudoers.d/${default_user}
  
  # Configure SSH for the user inside container
  lxc_exec mkdir -p /home/${default_user}/.ssh
  write_to_container "/home/${default_user}/.ssh/authorized_keys" "${ssh_pub_key}"
  lxc_exec chmod 700 /home/${default_user}/.ssh
  lxc_exec chmod 600 /home/${default_user}/.ssh/authorized_keys
  lxc_exec chown -R ${default_user}:${default_user} /home/${default_user}/.ssh
fi

# Run custom scripts inside container
%{ for script in custom_scripts ~}
echo "Running custom script inside container: ${script}"
# Replace password placeholders with actual password if applicable
%{ if generated_password != "" ~}
script_with_password=$(echo "${script}" | sed 's/PASSWORD_PLACEHOLDER/${generated_password}/g')
lxc_exec bash -c "$script_with_password"
%{ else ~}
lxc_exec bash -c "${script}"
%{ endif ~}
%{ endfor ~}

# Ensure SSH service is enabled and running inside container
lxc_exec systemctl enable ssh
lxc_exec systemctl start ssh

echo "LXC container initialization completed successfully for ${hostname}!"
exit 0
