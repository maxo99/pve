# # Centralized credential retrieval
module "vault_secrets" {
  source               = "./modules/vault-secrets"
  # api_credentials_path = var.vault_proxmox_credentials_path
}

locals {
  proxmox_credentials = module.vault_secrets.proxmox_api_credentials
  ssh_public_key      = module.vault_secrets.ssh_public_key
  ssh_private_key     = module.vault_secrets.ssh_private_key
  default_user        = var.default_user

  run_id = formatdate("YYYYMMDD-hhmm", timestamp())

}
