# # Centralized credential retrieval
module "vault_secrets" {
  source = "./modules/vault-secrets"
  api_credentials_path = var.vault_proxmox_credentials_path
}


locals {
  proxmox_credentials = module.vault_secrets.proxmox_api_credentials
  ssh_public_key      = module.vault_secrets.ssh_public_key
  ssh_private_key     = module.vault_secrets.ssh_private_key
  default_user        = var.default_user
  
  # Base cloud-init configuration common to all VMs
  base_cloud_init = templatefile("${path.module}/cloud-init/base-cloud-init.yml", {
    ssh_pub_key  = local.ssh_public_key
    default_user = local.default_user
  })
  
  # Scanning JSON configuration files for VMs and LXCs
  vm_files = fileset("${path.module}/config/vms/", "*.json")
  lxc_files = fileset("${path.module}/config/lxcs/", "*.json")
  
#   Load JSON files and convert them to configuration maps
  vm_configs = {
    for file in local.vm_files :
      trimsuffix(basename(file), ".json") => jsondecode(file("${path.module}/config/vms/${file}"))
  }
  
  lxc_configs = {
    for file in local.lxc_files :
      trimsuffix(basename(file), ".json") => jsondecode(file("${path.module}/config/lxcs/${file}"))
  }
}

# VM creation from configuration files
module "vms" {
  source   = "./modules/proxmox-vm"
  for_each = local.vm_configs
  
  # Common base parameters
  ssh_public_key        = local.ssh_public_key
  ssh_private_key       = local.ssh_private_key
  base_cloud_init       = local.base_cloud_init
  cloud_image_id        = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
  snippets_datastore_id = var.snippets_datastore_id
  default_user          = var.default_user
  
  # Specific parameters from JSON configuration
  vm_name           = each.value.vm_name
  vm_id             = each.value.vm_id
  node_name         = lookup(each.value, "node_name", var.default_node)
  description       = lookup(each.value, "description", "VM ${each.key}")
  tags              = lookup(each.value, "tags", [each.key])
  memory            = lookup(each.value, "memory", 2048)
  cores             = lookup(each.value, "cores", 2)
  disk_size         = lookup(each.value, "disk_size", 10)
  network_bridge    = lookup(each.value, "network_bridge", var.network_bridge)
  mac_address       = lookup(each.value, "mac_address", null)
  ip_config         = lookup(each.value, "ip_config", { ipv4_address = "dhcp", gateway = "" })
  datastore_id      = lookup(each.value, "datastore_id", var.default_datastore)
  packages          = lookup(each.value, "packages", [])
  custom_scripts    = lookup(each.value, "custom_scripts", [])
  start_on_boot     = lookup(each.value, "start_on_boot", false)
}

# LXC creation from configuration files
module "lxcs" {
  source   = "./modules/proxmox-lxc"
  for_each = local.lxc_configs
  
  # Common base parameters
  ssh_public_key          = local.ssh_public_key
  ansible_ssh_public_key  = module.vault_secrets.ansible_ssh_public_key
  proxmox_ssh_public_key  = module.vault_secrets.proxmox_ssh_public_key
  ssh_private_key         = local.ssh_private_key
  ostemplate_url          = proxmox_virtual_environment_download_file.ubuntu_container_template.id
  snippets_datastore_id   = var.snippets_datastore_id
  default_user            = var.default_user
  proxmox_host_ip         = var.proxmox_host_ip
  ssh_private_key_path    = var.ssh_private_key_path
  
  # Specific parameters from JSON configuration
  container_name    = each.value.container_name
  container_id      = each.value.container_id
  node_name         = lookup(each.value, "node_name", var.default_node)
  description       = lookup(each.value, "description", "Container LXC ${each.key}")
  tags              = lookup(each.value, "tags", [each.key])
  memory            = lookup(each.value, "memory", 2048)
  cores             = lookup(each.value, "cores", 2)
  disk_size         = lookup(each.value, "disk_size", 10)
  network_bridge    = lookup(each.value, "network_bridge", var.network_bridge)
  mac_address       = lookup(each.value, "mac_address", null)
  ip_config         = lookup(each.value, "ip_config", { ipv4_address = "dhcp", gateway = "" })
  datastore_id      = lookup(each.value, "datastore_id", var.default_datastore)
  feature_nesting   = lookup(each.value, "feature_nesting", false)
  unprivileged      = lookup(each.value, "unprivileged", true)
  packages          = lookup(each.value, "packages", [])
  custom_scripts    = lookup(each.value, "custom_scripts", [])
  start_on_boot     = lookup(each.value, "start_on_boot", false)
}
