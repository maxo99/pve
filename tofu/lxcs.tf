locals {

  # Scanning JSON configuration files for LXCs
  lxc_files      = fileset("${path.module}/config/lxcs/", "*.json")
  lxc_files_list = tolist(local.lxc_files)

  lxc_configs = {
    for idx, file in local.lxc_files_list :
    trimsuffix(basename(file), ".json") => merge(
      jsondecode(file("${path.module}/config/lxcs/${file}")),
      { lxc_idx = idx + 1 }
    )
  }
}

resource "proxmox_virtual_environment_download_file" "ubuntu_container_template" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = "pve-01"
  url          = "http://download.proxmox.com/images/system/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
}


# LXC creation from configuration files
module "lxcs" {
  source = "./modules/proxmox-lxc"
  providers = {
    proxmox = proxmox.lxc
  }
  for_each = local.lxc_configs
  # count     = length(local.lxc_configs)
  lxc_index = each.value.lxc_idx
  run_id    = local.run_id

  # Common base parameters
  ssh_public_key         = local.ssh_public_key
  ansible_ssh_public_key = module.vault_secrets.ansible_ssh_public_key
  proxmox_ssh_public_key = module.vault_secrets.proxmox_ssh_public_key
  ssh_private_key        = local.ssh_private_key
  ostemplate_url         = proxmox_virtual_environment_download_file.ubuntu_container_template.id
  snippets_datastore_id  = var.snippets_datastore_id
  default_user           = lookup(each.value, "default_user", var.default_user)
  proxmox_host_ip        = var.proxmox_host_ip
  ssh_private_key_path   = var.ssh_private_key_path

  # Specific parameters from JSON configuration
  container_name  = each.value.container_name
  container_id    = each.value.container_id
  node_name       = lookup(each.value, "node_name", var.default_node)
  description     = lookup(each.value, "description", "Container LXC ${each.key}")
  tags            = lookup(each.value, "tags", [each.key])
  memory          = lookup(each.value, "memory", 2048)
  cores           = lookup(each.value, "cores", 2)
  disk_size       = lookup(each.value, "disk_size", 10)
  network_bridge  = lookup(each.value, "network_bridge", var.network_bridge)
  mac_address     = lookup(each.value, "mac_address", null)
  ip_config       = lookup(each.value, "ip_config", { ipv4_address = "dhcp", gateway = "" })
  datastore_id    = lookup(each.value, "datastore_id", var.default_datastore)
  feature_nesting = lookup(each.value, "feature_nesting", false)
  unprivileged    = lookup(each.value, "unprivileged", true)
  packages        = lookup(each.value, "packages", [])
  custom_scripts  = lookup(each.value, "custom_scripts", [])
  start_on_boot   = lookup(each.value, "start_on_boot", false)
  mount_points    = lookup(each.value, "mount_points", [])

  # Password generation and Vault storage (optional)
  generate_admin_password = lookup(each.value, "generate_admin_password", false)
  admin_user              = lookup(each.value, "admin_user", "admin")
  vault_kv_path           = lookup(each.value, "vault_kv_path", "")
  ansible_playbook_path   = "../ansible"
}
