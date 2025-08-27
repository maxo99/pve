variable "vm_name" {
  description = "Name of the VM"
  type        = string
}

variable "node_name" {
  description = "Name of the Proxmox node"
  type        = string
}

variable "vm_id" {
  description = "ID of the VM"
  type        = number
}

variable "template_id" {
  description = "ID of the template to use for the VM (mutually exclusive with cloud_image_id)"
  type        = number
  default     = null
}

variable "cloud_image_id" {
  description = "ID of the cloud image to use for the VM (mutually exclusive with template_id)"
  type        = string
  default     = null
}

variable "datastore_id" {
  description = "ID of the datastore where the VM will be saved"
  type        = string
  default     = "local-lvm"
}

variable "snippets_datastore_id" {
  description = "ID of the datastore where cloud-init snippets will be saved"
  type        = string
  default     = "local"
}

variable "network_bridge" {
  description = "Network bridge to use"
  type        = string
  default     = "vmbr0"
}

variable "network_model" {
  description = "Network card model"
  type        = string
  default     = "virtio"
}

variable "mac_address" {
  description = "Custom MAC address for the VM"
  type        = string
  default     = null  # If null, it will be generated automatically
}

variable "ip_config" {
  description = "IP configuration of the VM"
  type = object({
    ipv4_address = string
    gateway      = string
  })
  default = {
    ipv4_address = "dhcp"
    gateway      = ""
  }
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

variable "base_cloud_init" {
  description = "Base cloud-init configuration common to all VMs"
  type        = string
  default     = ""  # If empty, the module's default template will be used  
}

variable "memory" {
  description = "Dedicated RAM memory in MB"
  type        = number
  default     = 2048
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "cpu_type" {
  description = "Type of CPU"
  type        = string
  default     = "x86-64-v2-AES"
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 20
}

variable "disk_iothread" {
  description = "Enable IOThread for the disk"
  type        = bool
  default     = true
}

variable "description" {
  description = "Description of the VM"
  type        = string
  default     = "VM created with OpenTofu"
}

variable "tags" {
  description = "Tags to assign to the VM"
  type        = list(string)
  default     = []
}

variable "agent_timeout" {
  description = "Timeout for waiting for the QEMU agent to become available"
  type        = string
  default     = "15m"
}

variable "start_on_boot" {
  description = "Automatically start the VM on node boot"
  type        = bool
  default     = false
}

variable "ssh_private_key" {
  description = "SSH private key for provisioning"
  type        = string
  default     = ""  # Default empty to make it optional
  sensitive   = true
}

variable "default_user" {
  description = "Default user for the container"
  type        = string
  default     = "ubuntu"
}
