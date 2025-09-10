# Track admin user configuration state
resource "null_resource" "configure_admin_user" {
  count = var.generate_admin_password ? 1 : 0
  
  lifecycle {
    ignore_changes = all
    # prevent_destroy = true
  }
}


# Generate a random password for admin user if enabled
resource "random_password" "admin_password" {
  count   = var.generate_admin_password ? 1 : 0
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Store the generated password in Vault
resource "null_resource" "store_password_in_vault" {
  count = var.generate_admin_password ? 1 : 0
  
  depends_on = [random_password.admin_password]
  
  lifecycle {
    ignore_changes = all
    # prevent_destroy = true
  }
  
  provisioner "local-exec" {
    when = create
    command = <<-EOT
      cd ${var.ansible_playbook_path}
      
      if [ -f .env ]; then
        set -a
        source .env
        set +a
      fi
      
      timeout 3 curl -s -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/sys/health" > /dev/null || { 
        echo 'Vault not accessible'; 
        exit 0; 
      }
      
      timeout 20 .venv/bin/ansible-playbook -i inventory/hosts.ini \
        vault_store_creds.yml \
        -e vault_secret_path="terraform/data/${var.vault_kv_path}" \
        -e vault_secret_data='{"${var.admin_user}":"${random_password.admin_password[0].result}"}' \
        || { echo 'Password storage failed'; exit 0; }
    EOT
    
    interpreter = ["/bin/bash", "-c"]
  }
}