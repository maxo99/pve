terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.81.0"
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

provider "vault" {
  address = var.vault_addr
  token   = var.vault_token

  skip_tls_verify = true
  max_retries     = var.vault_retry
}


provider "proxmox" {
  endpoint = var.proxmox_api_url
  username = "root@pam"
  password = module.vault_secrets.proxmox_root_password
  insecure = true
  
  ssh {
    agent = false
    username = "terraform-prov"
    private_key = module.vault_secrets.proxmox_ssh_private_key
    
    node {
      name    = var.default_node
      address = var.proxmox_host_ip
    }
  }
}
