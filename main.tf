variable "ci_ssh_keys" {
  type    = string
  default = ""
}
locals {
  ci_ssh_keys = trimspace(file("~/.ssh/pve/root.pub"))
}

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.80.0"
    }
    ansible = {
      source  = "ansible/ansible"
      version = ">= 1.3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
  }
}

# resource "proxmox_virtual_environment_file" "cloud_init" {
#   #  for_each          = var.VM_CONFIG
#    node_name     = "pve"
#    content_type  = "snippets"
#    datastore_id   = "snippets"

#   #  source_raw {
#   #     data = templatefile("${path.module}/cloud-init-template.yaml", {
#   #        ENVIRONMENT = each.value.ENVIRONMENT
#   #     })
#   #     file_name = "/snippets/snippets/${each.value.ENVIRONMENT}-init.yaml"
#   #  }
# }


provider "proxmox" {
  endpoint = var.proxmox_api_url
  username = var.proxmox_user
  password = var.proxmox_password
  insecure = true # Set to false if you have valid SSL certificates

  # THIS IS NOT SUPPORTED
  # timeout = 300 # 5 minutes instead of default


  # ssh {
  #       agent=false
  #       private_key = file("~/.ssh/pve/root")
  # }

  # ssh {
  #   agent    = true
  #   # username = var.proxmox_user # SSH username should be root for Proxmox
  #   username = "root"
  #   node {
  #     name    = "pve"
  #     address = var.proxmox_host_ip
  #   }
  # }


}
