#!/bin/bash
# cloud-init.sh - Cloud-init operations
# Usage: cloud-init.sh <command> <vm_id> [args...]

set -e

COMMAND="$1"
VM_ID="$2"
shift 2

if [ -z "$VM_ID" ]; then
    echo "Usage: $0 <command> <vm_id> [args...]"
    exit 1
fi

case "$COMMAND" in
    "dump")
        TYPE="${1:-user}"
        echo "=== Cloud-init $TYPE Data for VM $VM_ID ==="
        ssh pve-01 "qm cloudinit dump $VM_ID $TYPE"
        ;;
    "status")
        echo "=== Cloud-init Status for VM $VM_ID ==="
        if ssh pve-01 "qm agent $VM_ID ping" >/dev/null 2>&1; then
            echo "Via guest agent:"
            ssh pve-01 "qm guest exec $VM_ID -- cloud-init status" 2>/dev/null | jq -r '."out-data"' 2>/dev/null || echo "Cannot get cloud-init status"
        else
            echo "❌ Guest agent not responding - cannot check cloud-init status inside VM"
        fi
        ;;
    "logs")
        LOG_TYPE="${1:-main}"
        echo "=== Cloud-init Logs for VM $VM_ID ($LOG_TYPE) ==="
        if ssh pve-01 "qm agent $VM_ID ping" >/dev/null 2>&1; then
            case "$LOG_TYPE" in
                "main")
                    ssh pve-01 "qm guest exec $VM_ID -- tail -20 /var/log/cloud-init.log" 2>/dev/null | jq -r '."out-data"' 2>/dev/null
                    ;;
                "output")
                    ssh pve-01 "qm guest exec $VM_ID -- tail -20 /var/log/cloud-init-output.log" 2>/dev/null | jq -r '."out-data"' 2>/dev/null
                    ;;
                "all")
                    echo "Main log:"
                    ssh pve-01 "qm guest exec $VM_ID -- tail -10 /var/log/cloud-init.log" 2>/dev/null | jq -r '."out-data"' 2>/dev/null
                    echo -e "\nOutput log:"
                    ssh pve-01 "qm guest exec $VM_ID -- tail -10 /var/log/cloud-init-output.log" 2>/dev/null | jq -r '."out-data"' 2>/dev/null
                    ;;
                *)
                    echo "Unknown log type. Use: main, output, or all"
                    exit 1
                    ;;
            esac
        else
            echo "❌ Guest agent not responding - cannot access VM logs"
            exit 1
        fi
        ;;
    "validate-config")
        echo "=== Cloud-init Configuration Validation for VM $VM_ID ==="
        CONFIG=$(ssh pve-01 "qm config $VM_ID")
        CICUSTOM_LINE=$(echo "$CONFIG" | grep "^cicustom:" || echo "")
        IDE2_LINE=$(echo "$CONFIG" | grep "^ide2:" || echo "")

        echo "📋 Current Configuration:"
        if [ -n "$CICUSTOM_LINE" ]; then
            echo "  $CICUSTOM_LINE"
        else
            echo "  ⚠️  No cicustom configuration found"
        fi

        if [ -n "$IDE2_LINE" ]; then
            echo "  $IDE2_LINE"
        else
            echo "  ⚠️  No ide2 configuration found"
        fi

        # Validate snippet file exists
        if [ -n "$CICUSTOM_LINE" ]; then
            SNIPPET_FILE=$(echo "$CICUSTOM_LINE" | sed 's/.*user=local:snippets\/\([^,]*\).*/\1/')
            if [ -n "$SNIPPET_FILE" ]; then
                if ssh pve-01 "test -f /var/lib/vz/snippets/$SNIPPET_FILE"; then
                    echo "  ✅ Snippet file exists: $SNIPPET_FILE"
                else
                    echo "  ❌ Snippet file missing: $SNIPPET_FILE"
                fi
            fi
        fi
        ;;
    "fix-config")
        echo "=== Fixing Cloud-init Configuration for VM $VM_ID ==="
        VM_NAME=$(ssh pve-01 "qm config $VM_ID | grep '^name:' | cut -d':' -f2 | tr -d ' '")
        if [ -z "$VM_NAME" ]; then
            echo "❌ Cannot determine VM name"
            exit 1
        fi

        SNIPPET_FILE="$VM_ID-$VM_NAME-app-user-data.yml"
        echo "🔧 Setting cicustom configuration..."
        ssh pve-01 "qm set $VM_ID --cicustom user=local:snippets/$SNIPPET_FILE"

        echo "🔄 Rebooting VM to apply configuration..."
        ssh pve-01 "qm reset $VM_ID"

        echo "✅ VM rebooted. Wait 30-60 seconds then check cloud-init status"
        ;;
    *)
        echo "Usage: $0 <command> <vm_id> [args...]"
        echo "Commands:"
        echo "  dump [type]           - Dump cloud-init data (user/meta/vendor)"
        echo "  status                - Get cloud-init status"
        echo "  logs [type]           - Get cloud-init logs (main/output/all)"
        echo "  validate-config       - Validate cloud-init configuration"
        echo "  fix-config            - Fix cloud-init configuration"
        exit 1
        ;;
esac
