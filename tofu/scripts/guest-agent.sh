#!/bin/bash
# guest-agent.sh - QEMU Guest Agent operations
# Usage: guest-agent.sh <command> <vm_id> [args...]

set -e

COMMAND="$1"
VM_ID="$2"
shift 2

if [ -z "$VM_ID" ]; then
    echo "Usage: $0 <command> <vm_id> [args...]"
    exit 1
fi

case "$COMMAND" in
    "ping")
        if ssh pve-01 "qm agent $VM_ID ping" >/dev/null 2>&1; then
            echo "✅ Guest agent responding"
            exit 0
        else
            echo "❌ Guest agent not responding"
            exit 1
        fi
        ;;
    "status")
        echo "=== Guest Agent Status for VM $VM_ID ==="
        if ssh pve-01 "qm agent $VM_ID ping" >/dev/null 2>&1; then
            echo "✅ Guest agent responding"

            # Get basic info
            echo -e "\n📊 Basic Information:"
            ssh pve-01 "qm guest cmd $VM_ID get-osinfo" 2>/dev/null | jq . || echo "Cannot get OS info"

            echo -e "\n👥 Logged in users:"
            ssh pve-01 "qm guest cmd $VM_ID get-users" 2>/dev/null | jq . || echo "Cannot get user list"

            echo -e "\n💾 Memory statistics:"
            ssh pve-01 "qm guest cmd $VM_ID get-memory-stats" 2>/dev/null | jq . || echo "Cannot get memory stats"
        else
            echo "❌ Guest agent not responding"
            echo -e "\n🔧 Troubleshooting:"
            echo "1. Check if VM is running: qm status $VM_ID"
            echo "2. Check agent configuration: qm config $VM_ID | grep agent"
            echo "3. Check if qemu-guest-agent service is running inside VM"
        fi
        ;;
    "network-info")
        echo "=== Network Information for VM $VM_ID ==="
        if ssh pve-01 "qm agent $VM_ID ping" >/dev/null 2>&1; then
            ssh pve-01 "qm guest cmd $VM_ID 'network-get-interfaces'" | jq .
        else
            echo "❌ Guest agent not responding - cannot get network info"
            exit 1
        fi
        ;;
    "execute")
        CMD="$1"
        if [ -z "$CMD" ]; then
            echo "Usage: $0 execute <vm_id> <command>"
            exit 1
        fi
        echo "=== Executing command in VM $VM_ID ==="
        echo "Command: $CMD"
        ssh pve-01 "qm guest exec $VM_ID -- $CMD"
        ;;
    "file-read")
        FILE_PATH="$1"
        if [ -z "$FILE_PATH" ]; then
            echo "Usage: $0 file-read <vm_id> <file_path>"
            exit 1
        fi
        echo "=== Reading file from VM $VM_ID ==="
        echo "File: $FILE_PATH"
        ssh pve-01 "qm guest exec $VM_ID -- cat $FILE_PATH"
        ;;
    "service-status")
        SERVICE="$1"
        if [ -z "$SERVICE" ]; then
            echo "Usage: $0 service-status <vm_id> <service_name>"
            exit 1
        fi
        echo "=== Service Status for $SERVICE in VM $VM_ID ==="
        ssh pve-01 "qm guest exec $VM_ID -- systemctl is-active $SERVICE" 2>/dev/null || echo "Cannot check service status"
        ;;
    *)
        echo "Usage: $0 <command> <vm_id> [args...]"
        echo "Commands:"
        echo "  ping                    - Test guest agent connectivity"
        echo "  status                  - Get comprehensive guest agent status"
        echo "  network-info            - Get network interface information"
        echo "  execute <cmd>           - Execute command in VM"
        echo "  file-read <path>        - Read file contents from VM"
        echo "  service-status <svc>    - Check service status in VM"
        exit 1
        ;;
esac
