# Proxmox API credentials
output "proxmox_api_credentials" {
  value     = local.proxmox_api_credentials
  sensitive = true
}

# Proxmox root password for PAM authentication
output "proxmox_root_password" {
  value     = local.proxmox_root_password
  sensitive = true
}

# VM deployment SSH keys (for cloud-init injection)
output "ssh_public_key" {
  value     = local.ssh_public_key
  sensitive = true
}

output "ssh_private_key" {
  value     = local.ssh_private_key
  sensitive = true
}

# Proxmox host SSH keys (for Terraform snippet uploads)
output "proxmox_ssh_public_key" {
  value     = local.proxmox_ssh_public_key
  sensitive = true
}

output "proxmox_ssh_private_key" {
  value     = local.proxmox_ssh_private_key
  sensitive = true
}

# Ansible management SSH keys (for post-deployment configuration)
output "ansible_ssh_public_key" {
  value     = local.ansible_ssh_public_key
  sensitive = true
}

output "ansible_ssh_private_key" {
  value     = local.ansible_ssh_private_key
  sensitive = true
}
