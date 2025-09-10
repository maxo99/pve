#!/bin/bash
# pve-ssh.sh - SSH operations to PVE host
# Usage: pve-ssh.sh <command> [args...]

set -e

COMMAND="$1"
shift

case "$COMMAND" in
    "qm-status")
        VM_ID="$1"
        if [ -z "$VM_ID" ]; then
            echo "Usage: $0 qm-status <vm_id>"
            exit 1
        fi
        ssh pve-01 "qm status $VM_ID"
        ;;
    "qm-config")
        VM_ID="$1"
        if [ -z "$VM_ID" ]; then
            echo "Usage: $0 qm-config <vm_id>"
            exit 1
        fi
        ssh pve-01 "qm config $VM_ID"
        ;;
    "qm-agent-ping")
        VM_ID="$1"
        if [ -z "$VM_ID" ]; then
            echo "Usage: $0 qm-agent-ping <vm_id>"
            exit 1
        fi
        if ssh pve-01 "qm agent $VM_ID ping" >/dev/null 2>&1; then
            echo "Guest agent responding"
            exit 0
        else
            echo "Guest agent not responding"
            exit 1
        fi
        ;;
    "qm-guest-cmd")
        VM_ID="$1"
        GUEST_CMD="$2"
        if [ -z "$VM_ID" ] || [ -z "$GUEST_CMD" ]; then
            echo "Usage: $0 qm-guest-cmd <vm_id> <command>"
            exit 1
        fi
        ssh pve-01 "qm guest cmd $VM_ID $GUEST_CMD"
        ;;
    "qm-cloudinit-dump")
        VM_ID="$1"
        TYPE="${2:-user}"
        if [ -z "$VM_ID" ]; then
            echo "Usage: $0 qm-cloudinit-dump <vm_id> [type]"
            exit 1
        fi
        ssh pve-01 "qm cloudinit dump $VM_ID $TYPE"
        ;;
    "pct-status")
        LXC_ID="$1"
        if [ -z "$LXC_ID" ]; then
            echo "Usage: $0 pct-status <lxc_id>"
            exit 1
        fi
        ssh pve-01 "pct status $LXC_ID"
        ;;
    "pct-exec")
        LXC_ID="$1"
        EXEC_CMD="$2"
        if [ -z "$LXC_ID" ] || [ -z "$EXEC_CMD" ]; then
            echo "Usage: $0 pct-exec <lxc_id> <command>"
            exit 1
        fi
        ssh pve-01 "pct exec $LXC_ID -- $EXEC_CMD"
        ;;
    "list-vms")
        ssh pve-01 "qm list"
        ;;
    "list-lxcs")
        ssh pve-01 "pct list"
        ;;
    *)
        echo "Usage: $0 <command> [args...]"
        echo "Commands:"
        echo "  qm-status <vm_id>           - Get VM status"
        echo "  qm-config <vm_id>           - Get VM configuration"
        echo "  qm-agent-ping <vm_id>       - Test guest agent connectivity"
        echo "  qm-guest-cmd <vm_id> <cmd>  - Execute command via guest agent"
        echo "  qm-cloudinit-dump <vm_id>   - Dump cloud-init configuration"
        echo "  pct-status <lxc_id>         - Get LXC status"
        echo "  pct-exec <lxc_id> <cmd>     - Execute command in LXC"
        echo "  list-vms                    - List all VMs"
        echo "  list-lxcs                   - List all LXCs"
        exit 1
        ;;
esac
