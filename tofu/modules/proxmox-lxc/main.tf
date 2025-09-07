

resource "proxmox_virtual_environment_container" "lxc" {
  node_name           = var.node_name
  vm_id               = var.container_id
  description         = var.description
  tags                = var.tags
  start_on_boot       = var.start_on_boot
  unprivileged        = var.unprivileged
  started             = true
  hook_script_file_id = proxmox_virtual_environment_file.lxc_hook_script.id

  operating_system {
    template_file_id = var.template_id != null ? var.template_id : var.ostemplate_url
    type             = "ubuntu"
  }


  cpu {
    cores        = var.cores
    architecture = var.cpu_architecture
  }

  memory {
    dedicated = var.memory
    swap      = var.swap_memory
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.disk_size
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_bridge
    # mac_address = var.mac_address
    # firewall    = var.firewall
  }

  initialization {
    hostname = var.container_name

    ip_config {
      ipv4 {
        address = var.ip_config.ipv4_address
        gateway = var.ip_config.gateway != "" ? var.ip_config.gateway : null
      }
    }

    # User account configuration
    user_account {
      keys = [
        var.ssh_public_key,
        var.ansible_ssh_public_key,
        var.proxmox_ssh_public_key
      ]
      password = var.default_password
    }
  }

  features {
    fuse    = var.feature_fuse
    keyctl  = var.feature_keyctl
    nesting = var.feature_nesting
  }

  # Mount points configuration
  dynamic "mount_point" {
    for_each = var.mount_points
    content {
      path      = mount_point.value.container_path
      volume    = mount_point.value.host_path
      read_only = contains(split(",", mount_point.value.options), "ro")
      backup    = contains(split(",", mount_point.value.options), "backup")
      quota     = contains(split(",", mount_point.value.options), "quota")
    }
  }

}
