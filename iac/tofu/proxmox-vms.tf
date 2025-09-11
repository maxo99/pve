locals {
  vm_meta = yamldecode(file("${path.module}/config/meta.yml")).vm

  vm_configs = {
    for idx, config in local.vm_meta :
    config.vm_name => merge(config, { lxc_idx = idx + 1 })
  }

  # VM configuration processing
  processed_vm_configs = {
    for name, config in local.vm_configs :
    name => {
      # Basic VM settings
      vm_name     = config.vm_name
      vm_id       = config.vm_id
      vm_type     = lookup(config, "vm_type", "standard")
      node_name   = lookup(config, "node_name", var.default_node)
      description = lookup(config, "description", "VM ${name}")
      tags        = lookup(config, "tags", [name])

      # Hardware settings
      memory         = lookup(config, "memory", 2048)
      cores          = lookup(config, "cores", 2)
      disk_size      = lookup(config, "disk_size", 10)
      network_bridge = lookup(config, "network_bridge", var.network_bridge)
      mac_address    = lookup(config, "mac_address", null)
      datastore_id   = lookup(config, "datastore_id", var.default_datastore)

      # Type-specific settings
      is_haos = lookup(config, "vm_type", "standard") == "haos"

      # Image selection
      cloud_image_id = lookup(config, "vm_type", "standard") == "haos" ? proxmox_virtual_environment_download_file.haos_image[0].id : proxmox_virtual_environment_download_file.ubuntu_cloud_image.id

      # Network config
      ip_config = lookup(config, "ip_config", { ipv4_address = "dhcp", gateway = "" })

      # Software config
      packages       = lookup(config, "packages", [])
      custom_scripts = lookup(config, "custom_scripts", [])

      # Boot settings
      start_on_boot = lookup(config, "start_on_boot", true)
      agent_timeout = lookup(config, "agent_timeout", "10m")

      # User settings
      admin_user              = lookup(config, "admin_user", "admin")
      generate_admin_password = lookup(config, "generate_admin_password", false)
      vault_kv_path           = lookup(config, "vault_kv_path", "vm/passwords/${name}")
    }
  }

  # Check if any HAOS VMs exist
  has_haos_vms = length([for vm in local.vm_configs : vm if lookup(vm, "vm_type", "standard") == "haos"]) > 0
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
  count                   = local.has_haos_vms ? 1 : 0
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
  for_each = local.processed_vm_configs

  # Core VM parameters
  ssh_public_key        = local.ssh_public_key
  ssh_private_key       = local.ssh_private_key
  snippets_datastore_id = var.snippets_datastore_id
  default_user          = var.default_user
  ansible_playbook_path = "../ansible"

  # All processed configuration
  vm_name                 = each.value.vm_name
  vm_id                   = each.value.vm_id
  vm_type                 = each.value.vm_type
  node_name               = each.value.node_name
  description             = each.value.description
  tags                    = each.value.tags
  memory                  = each.value.memory
  cores                   = each.value.cores
  disk_size               = each.value.disk_size
  network_bridge          = each.value.network_bridge
  mac_address             = each.value.mac_address
  ip_config               = each.value.ip_config
  datastore_id            = each.value.datastore_id
  packages                = each.value.packages
  custom_scripts          = each.value.custom_scripts
  start_on_boot           = each.value.start_on_boot
  agent_timeout           = each.value.agent_timeout
  admin_user              = each.value.admin_user
  generate_admin_password = each.value.generate_admin_password
  vault_kv_path           = each.value.vault_kv_path
  cloud_image_id          = each.value.cloud_image_id
}


