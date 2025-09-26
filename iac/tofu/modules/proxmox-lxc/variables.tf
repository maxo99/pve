variable "container_name" {
  description = "Name of the LXC container"
  type        = string
}

variable "container_id" {
  description = "ID of the LXC container"
  type        = number
}

variable "proxmox_host_ip" {
  description = "IP address of the Proxmox host for SSH connections"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key for connecting to Proxmox host"
  type        = string
  default     = "~/.ssh/pve/root"
}

variable "node_name" {
  description = "Name of the Proxmox node"
  type        = string
}

variable "template_id" {
  description = "ID of the LXC template to use"
  type        = string
  default     = null
}

variable "template_os_type" {
  description = "Operating system type of the LXC template (e.g., ubuntu, debian)"
  type        = string
  default     = null
}

variable "generate_admin_password" {
  description = "Whether to generate and store an admin password in Vault"
  type        = bool
  default     = false
}

variable "default_admin_password" {
  description = "Default password for administrative users (root, admin)"
  type        = string
  sensitive   = true
}

variable "default_user_password" {
  description = "Default password for application users (postgres, redis, etc.)"
  type        = string
  sensitive   = true
}

variable "admin_user" {
  description = "Name of the admin user to create"
  type        = string
  default     = "admin"
}

variable "vault_kv_path" {
  description = "Vault KV path to store the generated password"
  type        = string
  default     = ""
}

variable "ansible_playbook_path" {
  description = "Path to the Ansible playbook for storing secrets"
  type        = string
  default     = "../ansible"
}

variable "default_user" {
  description = "ID of the datastore where to save the container"
  type        = string
  default     = "admin"
}

variable "datastore_id" {
  description = "ID of the datastore where to save the container"
  type        = string
  default     = "local-lvm"
}

variable "snippets_datastore_id" {
  description = "ID of the datastore where to save configuration snippets"
  type        = string
  default     = "local"
}

variable "network_bridge" {
  description = "Network bridge to use"
  type        = string
  default     = "vmbr0"
}

variable "mac_address" {
  description = "Custom MAC address for the container"
  type        = string
  default     = null # If null, it will be generated automatically
}

variable "firewall" {
  description = "Firewall"
  type        = bool
  default     = true
}

variable "ip_config" {
  description = "IP configuration for the container"
  type = object({
    ipv4_address = string
    gateway      = string
  })
  default = {
    ipv4_address = "dhcp"
    gateway      = ""
  }
}

variable "dns_servers" {
  description = "List of DNS servers"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
}

variable "packages" {
  description = "List of additional packages to install"
  type        = list(string)
  default     = []
}

variable "custom_scripts" {
  description = "Custom scripts to run post-installation"
  type        = list(string)
  default     = []
}

variable "ssh_public_key" {
  description = "SSH public key for access"
  type        = string
}

variable "ansible_ssh_public_key" {
  description = "Ansible SSH public key for management access"
  type        = string
}

variable "proxmox_ssh_public_key" {
  description = "Proxmox SSH public key for host access"
  type        = string
}

variable "ssh_private_key" {
  description = "SSH private key for provisioning"
  type        = string
  sensitive   = true
}


variable "base_cloud_init" {
  description = "Base cloud-init configuration for the container"
  type        = string
  default     = ""
}

variable "memory" {
  description = "Dedicated RAM in MB"
  type        = number
  default     = 512
}

variable "swap_memory" {
  description = "Swap memory in MB"
  type        = number
  default     = 512
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 1
}

# variable "cpu_units" {
#   description = "CPU units (1-10000)"
#   type        = number
#   default     = 1024
# }

variable "cpu_architecture" {
  description = "CPU architecture (x86_64, aarch64)"
  type        = string
  default     = "amd64"
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 8
}

variable "description" {
  description = "Description of the container"
  type        = string
  default     = "Container LXC created with OpenTofu"
}

variable "tags" {
  description = "Tags to assign to the container"
  type        = list(string)
  default     = []
}

variable "start_on_boot" {
  description = "Automatically start the container on node boot"
  type        = bool
  default     = true
}

variable "unprivileged" {
  description = "Create an unprivileged container"
  type        = bool
  default     = true
}

variable "feature_fuse" {
  description = "Enable FUSE support"
  type        = bool
  default     = false
}

variable "feature_keyctl" {
  description = "Enable keyctl support"
  type        = bool
  default     = false
}

variable "feature_nesting" {
  description = "Enable nesting (for Docker inside LXC)"
  type        = bool
  default     = false
}

variable "gpu_passthrough" {
  description = "Enable GPU passthrough for hardware acceleration (Intel iGPU)"
  type        = bool
  default     = false
}

variable "mount_points" {
  description = "List of mount points to bind from host to container"
  type = list(object({
    host_path      = string
    container_path = string
    options        = string # Comma-separated options like "bind,ro" - will be parsed into individual parameters
  }))
  default = []
}

variable "lxc_index" {
  description = "Index of the LXC container in a list (for internal use)"
  type        = number
  default     = 0
}

variable "run_id" {
  description = "Shared run ID for this deployment"
  type        = string
}

variable "config_path" {
  description = "Path to the configuration directory"
  type        = string
}
