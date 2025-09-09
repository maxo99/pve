#!/bin/bash

echo "Monitoring hook script execution for container ${container_name} (ID: ${container_id}, Run: ${run_id})..."

# Wait a moment for hook script to start
sleep 10

CONTAINER_ID="${container_id}"
RUN_ID="${run_id}"
STATUS_DIR="/tmp/$RUN_ID-lxc-$CONTAINER_ID-status"
CURRENT_STAGE=""
START_TIME=$(date +%s)

# Function to get elapsed time
get_elapsed_time() {
  local current_time=$(date +%s)
  local elapsed=$((current_time - START_TIME))
  local minutes=$((elapsed / 60))
  local seconds=$((elapsed % 60))
  if [ $minutes -gt 0 ]; then
    echo "$${minutes}m $${seconds}s"
  else
    echo "$${seconds}s"
  fi
}

# Function to check status via SSH
check_status() {
  ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "${ssh_private_key_path}" root@${proxmox_host_ip} "$1" 2>/dev/null || echo ""
}

# Monitor hook script progress
while true; do
  # Check if hook script completed successfully
  if [ "$(check_status "test -f $STATUS_DIR/SUCCESS && echo 'SUCCESS'")" = "SUCCESS" ]; then
    echo "Hook script completed successfully for ${container_name} ($(get_elapsed_time))"
    break
  fi
  
  # Check if hook script failed
  if [ "$(check_status "test -f $STATUS_DIR/FAILED && echo 'FAILED'")" = "FAILED" ]; then
    echo "Hook script failed for ${container_name} ($(get_elapsed_time))"
    echo "Error details:"
    check_status "tail -10 $STATUS_DIR/error.log 2>/dev/null || echo 'No error log available'"
    exit 1
  fi
  
  # Check current stage and report progress
  LATEST_STAGE=$(check_status "ls -1t $STATUS_DIR/*.status 2>/dev/null | head -1 | xargs basename -s .status" | head -1)
  
  if [ -n "$LATEST_STAGE" ] && [ "$LATEST_STAGE" != "$CURRENT_STAGE" ]; then
    case "$LATEST_STAGE" in
      "INIT")
        echo "Hook script started for ${container_name}"
        ;;
      "WAIT")
        echo "Waiting for container to be ready..."
        ;;
      "MOUNT_PREP")
        echo "Preparing mount points ($(get_elapsed_time))"
        ;;
      "SYSTEM_UPDATE")
        echo "System update in progress... (this may take 1-2 minutes)"
        ;;
      "USER_CONFIG")
        echo "Configuring user accounts ($(get_elapsed_time))"
        ;;
      "MOUNT_CONFIG")
        echo "Setting up container mount points ($(get_elapsed_time))"
        ;;
      "CUSTOM_SCRIPTS")
        echo "Running custom scripts ($(get_elapsed_time))"
        ;;
      "SSH_CONFIG")
        echo "Configuring SSH service ($(get_elapsed_time))"
        ;;
      "COMPLETED")
        echo "Finalizing container setup ($(get_elapsed_time))"
        ;;
    esac
    CURRENT_STAGE="$LATEST_STAGE"
  fi
  
  # Wait before next check
  sleep 30
  
  # Safety timeout (30 minutes)
  ELAPSED=$(($(date +%s) - START_TIME))
  if [ $ELAPSED -gt 1800 ]; then
    echo "Hook script monitoring timed out after 30 minutes for ${container_name}"
    echo "Last known status: $CURRENT_STAGE"
    echo "Container may still be functional. Check manually: ssh root@${proxmox_host_ip} 'ls -la $STATUS_DIR/'"
    break
  fi
done
