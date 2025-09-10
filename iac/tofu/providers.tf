terraform {
  backend "local" {
    path = ".tfstate/terraform.tfstate"
  }
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.83.0"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "1.3.0"
    }
    # null = {
    #   source  = "hashicorp/null"
    #   version = ">= 3.2"
    # }
  }
}


provider "proxmox" {
  endpoint = var.proxmox_api_url

  insecure  = true
  api_token = format("%s=%s", module.vault_secrets.proxmox_api_credentials.token_id, module.vault_secrets.proxmox_api_credentials.token_secret)

  ssh {
    agent    = true
    username = "root"
    private_key = module.vault_secrets.ssh_private_key
  }
}


# LXC snippets require root@pam
provider "proxmox" {
  alias    = "lxc"
  endpoint = var.proxmox_api_url
  username = "root@pam"
  password = module.vault_secrets.proxmox_root_password
  insecure = true
  
  ssh {
    agent    = true
    username = "root"
    private_key = module.vault_secrets.ssh_private_key
  }
}


provider "vault" {
  address = var.vault_addr
  token   = var.vault_token

  skip_tls_verify = true
  max_retries     = var.vault_retry
}
