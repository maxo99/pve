locals {
  # Scanning JSON configuration files for VMs
  vm_files = fileset("${path.module}/config/vms/", "*.json")

  # Load JSON files and convert them to configuration maps
  vm_configs = {
    for file in local.vm_files :
    trimsuffix(basename(file), ".json") => jsondecode(file("${path.module}/config/vms/${file}"))
  }
}


resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type        = "import"
  datastore_id        = "local"
  node_name           = "pve-01"
  url                 = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  file_name           = "jammy-server-cloudimg-amd64.qcow2"
  overwrite           = true
  overwrite_unmanaged = true
}

# VM creation from configuration files
module "vms" {
  source   = "./modules/proxmox-vm"
  for_each = local.vm_configs

  # Core VM parameters
  ssh_public_key        = local.ssh_public_key
  ssh_private_key       = local.ssh_private_key
  cloud_image_id        = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
  snippets_datastore_id = var.snippets_datastore_id
  default_user          = var.default_user

  # Specific parameters from JSON configuration
  vm_name        = each.value.vm_name
  vm_id          = each.value.vm_id
  node_name      = lookup(each.value, "node_name", var.default_node)
  description    = lookup(each.value, "description", "VM ${each.key}")
  tags           = lookup(each.value, "tags", [each.key])
  memory         = lookup(each.value, "memory", 2048)
  cores          = lookup(each.value, "cores", 2)
  disk_size      = lookup(each.value, "disk_size", 10)
  network_bridge = lookup(each.value, "network_bridge", var.network_bridge)
  mac_address    = lookup(each.value, "mac_address", null)
  ip_config      = lookup(each.value, "ip_config", { ipv4_address = "dhcp", gateway = "" })
  datastore_id   = lookup(each.value, "datastore_id", var.default_datastore)
  packages       = lookup(each.value, "packages", [])
  custom_scripts = lookup(each.value, "custom_scripts", [])
  start_on_boot  = lookup(each.value, "start_on_boot", false)
  agent_timeout  = lookup(each.value, "agent_timeout", "5m") # Reduced timeout to 5 minutes

  # Password generation and Vault storage (enable by default for VMs)
  admin_user              = lookup(each.value, "admin_user", "admin")
  generate_admin_password = lookup(each.value, "generate_admin_password", true)
  vault_kv_path           = lookup(each.value, "vault_kv_path", "vm/passwords/${each.key}")
  ansible_playbook_path   = "../ansible"
}


