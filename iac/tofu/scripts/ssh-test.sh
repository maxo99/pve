#!/bin/bash
# ssh-test.sh - SSH connection testing
# Usage: ssh-test.sh <command> [args...]

set -e

# Get Vault credentials
get_vault_creds() {
    VAULT_TOKEN="${VAULT_TOKEN:-$(grep VAULT_TOKEN .env 2>/dev/null | cut -d'=' -f2)}"
    VAULT_ADDR="${VAULT_ADDR:-$(grep VAULT_ADDR .env 2>/dev/null | cut -d'=' -f2)}"

    if [ -z "$VAULT_TOKEN" ] || [ -z "$VAULT_ADDR" ]; then
        echo "Error: VAULT_TOKEN and VAULT_ADDR must be set"
        exit 1
    fi
}

COMMAND="$1"
shift

case "$COMMAND" in
    "test-vm")
        VM_NAME="$1"
        IP="${2:-auto}"
        if [ -z "$VM_NAME" ]; then
            echo "Usage: $0 test-vm <vm_name> [ip]"
            exit 1
        fi

        # Get VM IP if not provided
        if [ "$IP" = "auto" ]; then
            IP=$(./get-vm-details.sh "$VM_NAME" ip_address)
            if [ -z "$IP" ] || [ "$IP" = "Not available" ]; then
                echo "❌ Cannot determine IP address for VM '$VM_NAME'"
                echo "💡 Try: $0 test-vm $VM_NAME <ip_address>"
                exit 1
            fi
        fi

        echo "=== SSH Test for VM: $VM_NAME at $IP ==="
        get_vault_creds

        SUCCESS=false
        for KEY_TYPE in vm_deployment ansible_management proxmox_host; do
            echo "Testing with $KEY_TYPE key..."
            TMP_KEY="/tmp/${KEY_TYPE}_test_key"
            curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/terraform/data/ssh_keys/$KEY_TYPE" | \
                jq -r '.data.data.private_key' > "$TMP_KEY"
            chmod 600 "$TMP_KEY"

            # Test different users
            for USER in ubuntu root; do
                if timeout 5 ssh -i "$TMP_KEY" -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$USER@$IP" "echo '✅ $KEY_TYPE ($USER): Success'" >/dev/null 2>&1; then
                    SUCCESS=true
                    echo "✅ $KEY_TYPE ($USER): Connection successful"
                    break 2
                fi
            done
            rm -f "$TMP_KEY"
        done

        if [ "$SUCCESS" = false ]; then
            echo "❌ All SSH connection attempts failed"
            exit 1
        fi
        ;;
    "test-lxc")
        LXC_NAME="$1"
        if [ -z "$LXC_NAME" ]; then
            echo "Usage: $0 test-lxc <lxc_name>"
            exit 1
        fi

        echo "=== SSH Test for LXC: $LXC_NAME ==="
        get_vault_creds

        # Get LXC IP
        IP=$(./get-lxc-details.sh "$LXC_NAME" ip)
        if [ -z "$IP" ] || [ "$IP" = "Not available" ] || [ "$IP" = "Container not running" ]; then
            echo "❌ Cannot determine IP address for LXC '$LXC_NAME'"
            exit 1
        fi

        echo "🌐 IP Address: $IP"

        SUCCESS=false
        for KEY_TYPE in vm_deployment ansible_management proxmox_host; do
            echo "Testing with $KEY_TYPE key..."
            TMP_KEY="/tmp/${KEY_TYPE}_test_key"
            curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/terraform/data/ssh_keys/$KEY_TYPE" | \
                jq -r '.data.data.private_key' > "$TMP_KEY"
            chmod 600 "$TMP_KEY"

            # Test different users
            for USER in root admin; do
                if timeout 5 ssh -i "$TMP_KEY" -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$USER@$IP" "echo '✅ $KEY_TYPE ($USER): Success'" >/dev/null 2>&1; then
                    SUCCESS=true
                    echo "✅ $KEY_TYPE ($USER): Connection successful"
                    break 2
                fi
            done
            rm -f "$TMP_KEY"
        done

        if [ "$SUCCESS" = false ]; then
            echo "❌ All SSH connection attempts failed"
            exit 1
        fi
        ;;
    "test-password")
        HOST="$1"
        USER="$2"
        PASSWORD="$3"
        if [ -z "$HOST" ] || [ -z "$USER" ] || [ -z "$PASSWORD" ]; then
            echo "Usage: $0 test-password <host> <user> <password>"
            exit 1
        fi

        echo "=== Password Authentication Test ==="
        echo "Host: $HOST"
        echo "User: $USER"

        if sshpass -p "$PASSWORD" ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no -o StrictHostKeyChecking=no "$USER@$HOST" "echo '✅ Password authentication successful'" >/dev/null 2>&1; then
            echo "✅ Password authentication successful"
        else
            echo "❌ Password authentication failed"
            exit 1
        fi
        ;;
    "test-lxc-batch")
        echo "=== Testing SSH Access to All LXC Containers ==="
        get_vault_creds

        # Get all LXC containers
        while IFS=$'\t' read -r key id name; do
            if [ -n "$id" ] && [ "$id" != "null" ]; then
                echo "Testing $name (ID: $id)..."
                ip=$(ssh pve-01 "pct exec $id -- ip addr show eth0 | grep 'inet ' | head -1 | awk '{print \$2}' | cut -d'/' -f1" 2>/dev/null)
                if [ -n "$ip" ]; then
                    echo "  IP: $ip"
                    SUCCESS=false
                    for KEY_TYPE in vm_deployment ansible_management proxmox_host; do
                        TMP_KEY="/tmp/${KEY_TYPE}_batch_key"
                        curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/terraform/data/ssh_keys/$KEY_TYPE" | \
                            jq -r '.data.data.private_key' > "$TMP_KEY"
                        chmod 600 "$TMP_KEY"

                        for USER in root admin; do
                            if timeout 5 ssh -i "$TMP_KEY" -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$USER@$ip" "echo '  SSH: ✅ Success ($KEY_TYPE/$USER)'" >/dev/null 2>&1; then
                                SUCCESS=true
                                break 2
                            fi
                        done
                        rm -f "$TMP_KEY"
                    done

                    if [ "$SUCCESS" = false ]; then
                        echo "  SSH: ❌ Failed for all key types"
                    fi
                else
                    echo "  No IP found"
                fi
            fi
        done < <(tofu output -json lxcs | jq -r 'to_entries[] | "\(.key)\t\(.value.id)\t\(.value.name)"')
        ;;
