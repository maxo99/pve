

# Dynamic template URLs based on OS type
locals {
  template_urls = {
    ubuntu = "http://download.proxmox.com/images/system/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
    debian = "http://download.proxmox.com/images/system/debian-12-standard_12.2-1_amd64.tar.zst"
  }
  
  selected_os_type = var.template_os_type != null ? var.template_os_type : "ubuntu"
  template_url = local.template_urls[local.selected_os_type]
}

resource "proxmox_virtual_environment_download_file" "container_template" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = var.node_name
  url          = local.template_url
  overwrite           = true
  overwrite_unmanaged = true
}

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
    template_file_id = var.template_id != null ? var.template_id : proxmox_virtual_environment_download_file.container_template.id
    type             = local.selected_os_type
  }


  lifecycle {
    ignore_changes = [
      hook_script_file_id,
      started
    ]
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
      password = var.default_admin_password
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

  startup {
    order      = var.lxc_index
    up_delay   = "60"
    down_delay = "60"
  }

  # # Monitor hook script execution status
  # provisioner "local-exec" {
  #   command = local.monitor_script
  # }

}

# Task monitoring for hookscript completion
resource "null_resource" "lxc_task_monitor" {
  depends_on = [proxmox_virtual_environment_container.lxc]

  provisioner "local-exec" {
    command = "touch /tmp/tofu-start-$$-${var.container_id} && ${path.module}/scripts/monitor-lxc-task.sh ${var.container_id} ${var.node_name} 600"
  }

  triggers = {
    container_id = var.container_id
    run_id       = var.run_id
  }
}
