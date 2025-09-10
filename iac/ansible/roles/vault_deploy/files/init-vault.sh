#!/bin/sh
set -euo pipefail

# CONFIGURATIONS
POLICY_NAME="ci-policy"
ROLE_NAME="ci-role"
SECRET_PATHS="ansible terraform"
VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:?VAULT_TOKEN missing}"
FORCE_RECREATE_SSH_KEYS="${FORCE_RECREATE_SSH_KEYS:-false}"

# Install dependencies
apk add jq

echo "[+] Init Vault..."

# Enable all secret engines specified in the array
for SECRET_PATH in $SECRET_PATHS; do
  if vault secrets list -format=json | jq -e ".[\"$SECRET_PATH/\"]" > /dev/null 2>&1; then
    echo "[+] Secret engine '$SECRET_PATH/' already enabled."
  else
    echo "[+] Enabling secret engine '$SECRET_PATH/' (kv-v2)..."
    vault secrets enable -path="$SECRET_PATH" -version=2 kv
  fi
done

# Check if Approle auth method is already enabled
if vault auth list -format=json | jq -e '."approle/"' > /dev/null 2>&1; then
  echo "[+] Auth method AppRole already enabled."
else
  echo "[+] Enabling auth method AppRole..."
  vault auth enable approle
fi

# Create policy
echo "[+] Writing policy '$POLICY_NAME'..."

# Delete existing policy if present
vault policy delete "$POLICY_NAME" 2>/dev/null || true

vault policy write "$POLICY_NAME" - <<'POLICY_EOF'
path "ansible/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "terraform/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "auth/token/create" {
  capabilities = ["update"]
}
POLICY_EOF

# Check if role is already created
if vault read -format=json "auth/approle/role/$ROLE_NAME" > /dev/null 2>&1; then
  echo "[+] Role AppRole '$ROLE_NAME' already existing."
else
  echo "[+] Creating role AppRole '$ROLE_NAME'..."
  vault write "auth/approle/role/$ROLE_NAME" \
    token_policies="$POLICY_NAME" \
    token_ttl="3600" \
    token_max_ttl="7200"
fi

# Get role_id (fixed for the role)
ROLE_ID=$(vault read -field=role_id "auth/approle/role/$ROLE_NAME/role-id")

# Create new secret_id (this is always one-time-use)
SECRET_ID=$(vault write -f -field=secret_id "auth/approle/role/$ROLE_NAME/secret-id")

# Generate SSH keys for infrastructure
echo ""
echo "[+] Generating SSH keys for infrastructure..."

# Install openssh-client for ssh-keygen
apk add openssh-client

# Check if SSH keys already exist in Vault before generating new ones
SSH_KEYS_EXIST=true

if [ "$FORCE_RECREATE_SSH_KEYS" = "true" ]; then
  echo "[+] FORCE_RECREATE_SSH_KEYS=true - Forcing SSH key recreation..."
  SSH_KEYS_EXIST=false
else
  for key_path in "terraform/data/ssh_keys/proxmox_host" "terraform/data/ssh_keys/vm_deployment" "terraform/data/ssh_keys/ansible_management"; do
    if ! vault kv get "$key_path" > /dev/null 2>&1; then
      SSH_KEYS_EXIST=false
      break
    fi
  done
fi

if [ "$SSH_KEYS_EXIST" = "true" ]; then
  echo "[+] SSH keys already exist in Vault. Skipping key generation."
  echo "    To regenerate keys, either:"
  echo "    1. Set FORCE_RECREATE_SSH_KEYS=true environment variable"
  echo "    2. Or delete them manually with:"
  echo "       vault kv delete terraform/data/ssh_keys/proxmox_host"
  echo "       vault kv delete terraform/data/ssh_keys/vm_deployment"
  echo "       vault kv delete terraform/data/ssh_keys/ansible_management"
else
  if [ "$FORCE_RECREATE_SSH_KEYS" = "true" ]; then
    echo "[+] Force recreating SSH keys (overwriting existing keys)..."
  else
    echo "[+] Generating new SSH keys..."
  fi
  
  # Generate SSH keys (ed25519 for better security)
  ssh-keygen -t ed25519 -f /tmp/proxmox_host_key -N "" -C "terraform-proxmox-$(date +%Y%m%d)"
  ssh-keygen -t ed25519 -f /tmp/vm_deployment_key -N "" -C "terraform-vm-$(date +%Y%m%d)"
  ssh-keygen -t ed25519 -f /tmp/ansible_management_key -N "" -C "ansible-mgmt-$(date +%Y%m%d)"

  # Store SSH keys in Vault KV
  echo "[+] Storing SSH keys in Vault..."

  vault kv put terraform/data/ssh_keys/proxmox_host \
    private_key="$(cat /tmp/proxmox_host_key)" \
    public_key="$(cat /tmp/proxmox_host_key.pub)"

  vault kv put terraform/data/ssh_keys/vm_deployment \
    private_key="$(cat /tmp/vm_deployment_key)" \
    public_key="$(cat /tmp/vm_deployment_key.pub)"

  vault kv put terraform/data/ssh_keys/ansible_management \
    private_key="$(cat /tmp/ansible_management_key)" \
    public_key="$(cat /tmp/ansible_management_key.pub)"

  # Clean up temporary files
  rm -f /tmp/*_key /tmp/*_key.pub
  
  echo "[+] New SSH keys generated and stored in Vault."
fi

# Output
echo ""
echo "[+] AppRole successfully configured:"
echo "export VAULT_ROLE_ID=\"$ROLE_ID\""
echo "export VAULT_SECRET_ID=\"$SECRET_ID\""
echo ""
echo "[+] SSH Keys status in Vault:"
echo "  - terraform/data/ssh_keys/proxmox_host"
echo "  - terraform/data/ssh_keys/vm_deployment" 
echo "  - terraform/data/ssh_keys/ansible_management"
