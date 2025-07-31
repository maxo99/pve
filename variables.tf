variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}
variable "proxmox_user" {
  description = "Proxmox user for API access"
  type        = string
}
variable "proxmox_password" {
  description = "Proxmox password for API access"
  type        = string
  sensitive   = true
}
variable "ci_username" {
  description = "Cloud-Init username"
  type        = string
  default     = "root"
}

variable "ci_password" {
  description = "Cloud-Init password"
  type        = string
  sensitive   = true

}
locals {
  ci_ssh_keys = file("~/.ssh/pve/cloud-init.pub")
}

variable "ci_ssh_keys" {
  description = "Cloud-Init SSH keys"
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
  default     = "192.168.6.150/22" # Match the /22 from ci_ipconfig
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
