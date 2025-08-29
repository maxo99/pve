data "vault_generic_secret" "ssh_proxmox_host" {
  path = "terraform/ssh_keys/proxmox_host"
}

data "vault_generic_secret" "ssh_vm_deployment" {
  path = "terraform/ssh_keys/vm_deployment"
}

data "vault_generic_secret" "ssh_ansible_management" {
  path = "terraform/ssh_keys/ansible_management"
}

data "vault_generic_secret" "proxmox_api_credentials" {
  path = var.api_credentials_path
}

data "vault_generic_secret" "proxmox_pam_login" {
  path = "terraform/login/pam"
}

# Structure data for the main module
locals {
  # Proxmox API credentials
  proxmox_api_credentials = {
    token_id     = lookup(data.vault_generic_secret.proxmox_api_credentials.data, "token_id", null)
    token_secret = lookup(data.vault_generic_secret.proxmox_api_credentials.data, "token_secret", null)
  }
  
  # Proxmox PAM login credentials
  proxmox_root_password = data.vault_generic_secret.proxmox_pam_login.data["root"]
  
  # Primary SSH keys for VM deployment (used in cloud-init)
  ssh_public_key = data.vault_generic_secret.ssh_vm_deployment.data["public_key"]
  ssh_private_key = data.vault_generic_secret.ssh_vm_deployment.data["private_key"]

  # Proxmox host SSH keys (for Terraform to upload snippets)
  proxmox_ssh_public_key = data.vault_generic_secret.ssh_proxmox_host.data["public_key"]
  proxmox_ssh_private_key = data.vault_generic_secret.ssh_proxmox_host.data["private_key"]
  
  # Ansible management SSH keys (for post-deployment config)
  ansible_ssh_public_key = data.vault_generic_secret.ssh_ansible_management.data["public_key"]
  ansible_ssh_private_key = data.vault_generic_secret.ssh_ansible_management.data["private_key"]
}
