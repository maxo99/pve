output "ssh_key_fingerprint" { 
  value = module.vault_secrets.proxmox_ssh_public_key 
  sensitive = true
}
