locals {

  vm_meta = yamldecode(file("${path.module}/config/meta.yml")).vm

  vm_configs = {
    for idx, config in local.vm_meta :
    config.vm_name => merge(config, { lxc_idx = idx + 1 })
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


# Download HAOS image for HAOS VMs using ZST decompression for XZ files
resource "proxmox_virtual_environment_download_file" "haos_image" {
  count                   = length([for vm in local.vm_configs : vm if lookup(vm, "vm_type", "standard") == "haos"]) > 0 ? 1 : 0
  content_type            = "iso"
  datastore_id            = "local"
  node_name               = "pve-01"
  url                     = "https://github.com/home-assistant/operating-system/releases/download/16.2/haos_ova-16.2.qcow2.xz"
  file_name               = "haos_ova-16.2.qcow2.xz.img"
  decompression_algorithm = "zst"
  overwrite               = true
  overwrite_unmanaged     = true
}

# VM creation from configuration files
module "vms" {
  source   = "./modules/proxmox-vm"
  for_each = local.vm_configs

  # Core VM parameters
  ssh_public_key        = local.ssh_public_key
  ssh_private_key       = local.ssh_private_key
  cloud_image_id        = lookup(each.value, "vm_type", "standard") == "haos" ? (length(proxmox_virtual_environment_download_file.haos_image) > 0 ? proxmox_virtual_environment_download_file.haos_image[0].id : null) : proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
  snippets_datastore_id = var.snippets_datastore_id
  default_user          = var.default_user

  # Specific parameters from configuration
  vm_name        = each.value.vm_name
  vm_id          = each.value.vm_id
  vm_type        = lookup(each.value, "vm_type", "standard")
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
  start_on_boot  = lookup(each.value, "start_on_boot", true)
  agent_timeout  = lookup(each.value, "agent_timeout", "10m")

  # Password generation and Vault storage (enable by default for VMs)
  admin_user              = lookup(each.value, "admin_user", "admin")
  generate_admin_password = lookup(each.value, "generate_admin_password", false)
  vault_kv_path           = lookup(each.value, "vault_kv_path", "vm/passwords/${each.key}")
  ansible_playbook_path   = "../ansible"

  # # Ensure HAOS image is downloaded before VM creation
  # depends_on = lookup(each.value, "vm_type", "standard") == "haos" ? [null_resource.haos_image_download[0]] : []
}


