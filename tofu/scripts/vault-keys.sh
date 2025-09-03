#!/bin/bash
# vault-keys.sh - Vault SSH key operations
# Usage: vault-keys.sh <command> [args...]

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
    "get-public-key")
        KEY_TYPE="$1"
        if [ -z "$KEY_TYPE" ]; then
            echo "Usage: $0 get-public-key <key_type>"
            echo "Key types: vm_deployment, ansible_management, proxmox_host"
            exit 1
        fi
        get_vault_creds
        curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/terraform/data/ssh_keys/$KEY_TYPE" | \
            jq -r '.data.data.public_key'
        ;;
    "get-private-key")
        KEY_TYPE="$1"
        OUTPUT_FILE="${2:-/tmp/${KEY_TYPE}_key}"
        if [ -z "$KEY_TYPE" ]; then
            echo "Usage: $0 get-private-key <key_type> [output_file]"
            echo "Key types: vm_deployment, ansible_management, proxmox_host"
            exit 1
        fi
        get_vault_creds
        curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/terraform/data/ssh_keys/$KEY_TYPE" | \
            jq -r '.data.data.private_key' > "$OUTPUT_FILE"
        chmod 600 "$OUTPUT_FILE"
        echo "Private key saved to: $OUTPUT_FILE"
        ;;
    "list-keys")
        get_vault_creds
        echo "Available SSH keys in Vault:"
        curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/terraform/metadata/ssh_keys/?list=true" | \
            jq -r '.data.keys[]'
        ;;
    "test-connection")
        KEY_TYPE="$1"
        HOST="$2"
        USER="${3:-root}"
        if [ -z "$KEY_TYPE" ] || [ -z "$HOST" ]; then
            echo "Usage: $0 test-connection <key_type> <host> [user]"
            exit 1
        fi
        get_vault_creds
        TMP_KEY="/tmp/${KEY_TYPE}_test_key"
        curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/terraform/data/ssh_keys/$KEY_TYPE" | \
            jq -r '.data.data.private_key' > "$TMP_KEY"
        chmod 600 "$TMP_KEY"

        if ssh -i "$TMP_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$USER@$HOST" "echo 'SSH connection successful'" >/dev/null 2>&1; then
            echo "SSH connection successful"
            rm -f "$TMP_KEY"
            exit 0
        else
            echo "SSH connection failed"
            rm -f "$TMP_KEY"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 <command> [args...]"
        echo "Commands:"
        echo "  get-public-key <key_type>           - Get public key from Vault"
        echo "  get-private-key <key_type> [file]   - Get private key from Vault"
        echo "  list-keys                           - List available keys in Vault"
        echo "  test-connection <key_type> <host>   - Test SSH connection with key"
        echo ""
        echo "Key types: vm_deployment, ansible_management, proxmox_host"
        exit 1
        ;;
esac
