#!/bin/bash
# Hook script orchestrator for LXC ${container_id} (${container_name})
set -e

VMID="$1"
PHASE="$2"

# Only run during post-start phase
if [ "$PHASE" != "post-start" ]; then
    exit 0
fi

# Container filesystem path
CT_PATH="/var/lib/lxc/$VMID/rootfs"
STAGE_DIR="/root/.lxc-confs"

echo "Starting LXC container initialization for ${container_name} (ID: $VMID) at $(date +%s)"

# Wait for container to be ready
sleep 20

# Prepare staging directory inside container for managed config files
lxc-attach -n "$VMID" -- mkdir -p "$STAGE_DIR"
lxc-attach -n "$VMID" -- chown root:root "$STAGE_DIR"
lxc-attach -n "$VMID" -- chmod 0755 "$STAGE_DIR"

# Function to execute commands inside the container
lxc_exec() {
    lxc-attach -n "$VMID" -- "$@"
}

# Function to source helpers inside container commands
lxc_exec_with_helpers() {
    lxc-attach -n "$VMID" -- /bin/bash -c "source /tmp/lxc-helpers.sh && $*"
}

# Ensure host-side mount point directories exist and have appropriate permissions
%{ for mount_point in mount_points ~}
echo "Ensuring host directory exists: ${mount_point.host_path}"
mkdir -p "${mount_point.host_path}" || { echo "Failed to create directory ${mount_point.host_path}"; exit 1; }

# Set appropriate permissions on host side for mount points
chown -R 100000:100000 "${mount_point.host_path}" 2>/dev/null || echo "Warning: Could not change ownership of ${mount_point.host_path}"
chmod -R 755 "${mount_point.host_path}" 2>/dev/null || echo "Warning: Could not change permissions of ${mount_point.host_path}"
%{ endfor ~}

# Copy helpers to container
echo "Copying helpers to container..."
lxc-attach -n "$VMID" -- /bin/bash -c "cat > /tmp/lxc-helpers.sh" < /var/lib/vz/snippets/lxc_helpers.sh
lxc_exec chmod +x /tmp/lxc-helpers.sh

# Install base packages
echo "Installing base packages..."
lxc_exec_with_helpers "ensure_packages ${packages}"

# User setup and SSH configuration
echo "Setting up user and SSH..."
user_setup_script='
ensure_user "${default_user}" "/home/${default_user}" "/bin/bash"
echo "${default_user} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${default_user}
chmod 440 /etc/sudoers.d/${default_user}
ensure_directory "/home/${default_user}/.ssh" "${default_user}:${default_user}" "700"
cat > /home/${default_user}/.ssh/authorized_keys << EOF
${ssh_pub_key}
${ansible_ssh_pub_key}
${proxmox_ssh_pub_key}
EOF
chmod 600 /home/${default_user}/.ssh/authorized_keys
chown ${default_user}:${default_user} /home/${default_user}/.ssh/authorized_keys
'
lxc_exec_with_helpers "$user_setup_script"

# Mount point configuration (container side)
echo "Creating container mount point directories..."
%{ for mount_point in mount_points ~}
lxc_exec_with_helpers "ensure_directory '${mount_point.container_path}' 'root:root' '755'"
%{ endfor ~}

# Ensure SSH service is running
echo "Starting SSH service..."
lxc_exec_with_helpers "ensure_service_running ssh"

%{ if length(pre_conf_files) > 0 ~}
# Apply pre-install configuration files
echo "Applying pre-install configuration files..."
%{ for cf in pre_conf_files ~}
echo " - Installing ${cf.dest} (pre)"
SNIP_FILE="/var/lib/vz/snippets/${container_id}-${container_name}-${replace(basename(cf.src), ".", "_")}" 
DEST_PATH="${cf.dest}"
PARENT_DIR="$(dirname "$DEST_PATH")"
lxc-attach -n "$VMID" -- /bin/sh -lc "echo 'Ensuring directory: ' \"$PARENT_DIR\""
lxc-attach -n "$VMID" -- mkdir -p "$PARENT_DIR"
if [ ! -f "$SNIP_FILE" ]; then
    echo "WARNING: Snippet file not found: $SNIP_FILE (skipping ${cf.dest})"
else
lxc-attach -n "$VMID" -- mkdir -p "$PARENT_DIR"
lxc-attach -n "$VMID" -- /bin/sh -c "cat > \"$DEST_PATH\"" < "$SNIP_FILE"
lxc-attach -n "$VMID" -- chown root:root "$DEST_PATH"
lxc-attach -n "$VMID" -- chmod 0644 "$DEST_PATH"
    lxc-attach -n "$VMID" -- /bin/sh -lc "ls -l \"$DEST_PATH\" || true"
    # Always stage a copy for downstream (e.g., Ansible) consumption
    STAGE_DEST="$STAGE_DIR$DEST_PATH"
    STAGE_PARENT="$(dirname "$STAGE_DEST")"
    lxc-attach -n "$VMID" -- mkdir -p "$STAGE_PARENT"
    lxc-attach -n "$VMID" -- /bin/sh -c "cat > \"$STAGE_DEST\"" < "$SNIP_FILE"
    lxc-attach -n "$VMID" -- chown root:root "$STAGE_DEST"
    lxc-attach -n "$VMID" -- chmod 0644 "$STAGE_DEST"
    lxc-attach -n "$VMID" -- /bin/sh -lc "echo 'Staged at: ' \"$STAGE_DEST\" && ls -l \"$STAGE_DEST\" || true"
fi
%{ endfor ~}
%{ endif ~}

%{ if has_init_script ~}
# Copy and execute the native custom script
echo "Copying custom script to container..."
lxc-attach -n "$VMID" -- /bin/bash -c "cat > /tmp/custom-init.sh" < /var/lib/vz/snippets/${container_id}-${container_name}-init.sh
lxc_exec chmod +x /tmp/custom-init.sh

%{ if generated_admin_password != "" ~}
# Replace admin password placeholders with actual password if applicable
echo "Replacing admin password placeholders..."
lxc_exec sed -i 's/ADMIN_PASSWORD_PLACEHOLDER/${generated_admin_password}/g' /tmp/custom-init.sh
%{ endif ~}

%{ if generated_user_password != "" ~}
# Replace user password placeholders with actual password if applicable
echo "Replacing user password placeholders..."
lxc_exec sed -i 's/PASSWORD_PLACEHOLDER/${generated_user_password}/g' /tmp/custom-init.sh
%{ endif ~}

echo "Executing custom script..."
lxc_exec /tmp/custom-init.sh

# Clean up temporary files in container
echo "Cleaning up temporary files..."
lxc_exec rm -f /tmp/custom-init.sh
%{ else ~}
echo "No custom initialization needed"
%{ endif ~}

%{ if length(post_conf_files) > 0 ~}
# Stage post-install configuration files (do not apply to final destinations here)
POST_CONF_MARKER="/etc/.lxc_post_confs_staged"
if lxc-attach -n "$VMID" -- test -f "$POST_CONF_MARKER"; then
    echo "Post-install configuration already staged; skipping."
else
    echo "Waiting for services to settle before staging post-install configuration files..."
    sleep 10
    echo "Staging post-install configuration files to $STAGE_DIR..."
    %{ for cf in post_conf_files ~}
    echo " - Staging ${cf.dest} (post)"
    SNIP_FILE="/var/lib/vz/snippets/${container_id}-${container_name}-${replace(basename(cf.src), ".", "_")}" 
    DEST_PATH="${cf.dest}"
    STAGE_DEST="$STAGE_DIR$DEST_PATH"
    STAGE_PARENT="$(dirname "$STAGE_DEST")"
    if [ ! -f "$SNIP_FILE" ]; then
        echo "WARNING: Snippet file not found: $SNIP_FILE (skipping stage for ${cf.dest})"
    else
        lxc-attach -n "$VMID" -- mkdir -p "$STAGE_PARENT"
        lxc-attach -n "$VMID" -- /bin/sh -c "cat > \"$STAGE_DEST\"" < "$SNIP_FILE"
        lxc-attach -n "$VMID" -- chown root:root "$STAGE_DEST"
        lxc-attach -n "$VMID" -- chmod 0644 "$STAGE_DEST"
        lxc-attach -n "$VMID" -- /bin/sh -lc "ls -l \"$STAGE_DEST\" || true"
    fi
    %{ endfor ~}
    # Create marker so this section runs only once
    lxc-attach -n "$VMID" -- /bin/sh -c "date -u > \"$POST_CONF_MARKER\""
fi
%{ endif ~}

# Clean up helpers file in container
lxc_exec rm -f /tmp/lxc-helpers.sh

echo "LXC initialization completed for ${container_name} at $(date +%s)"

# Create success marker
echo "Success at $(date +%s)" > /tmp/${run_id}-lxc-$VMID-init.log

# Final cleanup
jobs -p | xargs -r kill 2>/dev/null || true
sync

exit 0
