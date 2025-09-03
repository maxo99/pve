variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}
variable "proxmox_host_ip" {
  description = "Proxmox host IP address for SSH connections"
  type        = string
}
# Proxmox connection (credentials now from Vault)
# variable "proxmox_user" {
#   description = "Proxmox user for API access - now from Vault"
#   type        = string
# }
# variable "proxmox_password" {
#   description = "Proxmox password for API access - now from Vault"
#   type        = string
#   sensitive   = true
# }
# variable "proxmox_ssh" {
#   type        = string
#   description = "SSH connection string for Proxmox host (e.g., user@proxmox-host)"
# }
#
## Datastore and network configurations
variable "snippets_datastore_id" {
  description = "Datastore for cloud-init snippets"
  type        = string
  default     = "local"
}
variable "default_user" {
  description = "Nome utente SSH predefinito per le VM"
  type        = string
  default     = "admin"
}
variable "default_node" {
  description = "Default Proxmox node for VMs and containers"
  type        = string
}
variable "network_bridge" {
  description = "Default network bridge for VMs and containers"
  type        = string
  default     = "vmbr0"
}
variable "default_datastore" {
  description = "Default datastore for VMs and containers"
  type        = string
  default     = "local-lvm"
}
#
## Cloud-Init configuration variables
variable "ci_username" {
  description = "Cloud-Init username"
  type        = string
  default     = "admin"
}
variable "ci_password" {
  description = "Cloud-Init password"
  type        = string
  sensitive   = true

}
variable "ci_nameserver" {
  description = "Cloud-Init nameservers"
  type        = string
  default     = "1.1.1.1 8.8.8.8"
  validation {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}( (\\d{1,3}\\.){3}\\d{1,3})*$", var.ci_nameserver))
    error_message = "Invalid nameserver format"
  }
}
variable "ci_ipconfig" {
  description = "Cloud-Init IP configuration"
  type        = string
  default     = "ip=192.168.6.150/22,gw=192.168.4.1"
  validation {
    condition     = can(regex("^ip=\\d{1,3}(\\.\\d{1,3}){3}/\\d{1,2},gw=\\d{1,3}(\\.\\d{1,3}){3}(,ip6=dhcp)?$", var.ci_ipconfig))
    error_message = "Invalid IP configuration format"
  }
}
variable "ci_ip_address" {
  description = "Cloud-Init IP address with CIDR"
  type        = string
  default     = "192.168.6.150/22"
}
variable "ci_gateway" {
  description = "Cloud-Init gateway IP"
  type        = string
  default     = "192.168.4.1"
}
variable "ci_skip_ipv6" {
  description = "Skip IPv6 configuration in Cloud-Init"
  type        = bool
  default     = true
}
variable "ssh_private_key_path" {
  description = "Path to the SSH private key for Ansible"
  type        = string
  default     = "~/.ssh/pve/root"
}
# variable "ci_ssh_keys" {
#   description = "Cloud-Init SSH keys"
#   type        = string
#   sensitive   = true

# }

variable "install_ssh" {
  type    = bool
  default = true
}
variable "lxc1_ip_address" {
  type        = string
  description = "LXC 1 IP address"
}
variable "lxc2_ip_address" {
  type        = string
  description = "LXC 2 IP address"
}

# Vault Configuration
variable "vault_addr" {
  description = "Vault server address"
  type        = string
  default     = "http://vault:8200"
}

variable "vault_url" {
  description = "Vault server URL for containers"
  type        = string
  default     = "http://192.168.6.3:8200"
}

variable "vault_token" {
  description = "Vault token for authentication"
  type        = string
  sensitive   = true
}

variable "vault_proxmox_credentials_path" {
  description = "Path in Vault where Proxmox credentials are stored"
  type        = string
}


variable "vault_retry" {
  description = "Number of retry attempts for Vault operations"
  type        = number
  default     = 3
}

# variable "default_lxc_template" {
#   description = "Default LXC template for container creation"
#   type        = string
#   default     = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
# }

variable "virtual_environment_token" {
  type        = string
  description = "The token for the Proxmox Virtual Environment API"
}

