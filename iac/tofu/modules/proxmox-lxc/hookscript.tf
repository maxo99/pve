
locals {

  hook_file_name = "${var.container_id}-${var.container_name}-hook.sh"
  # Read custom script files and prepare their content
  custom_script_contents = [
    for script_file in var.custom_scripts :
    file("${var.config_path}/lxcs/hookscripts/${script_file}")
  ]
}


# Shared helpers file for all LXCs
resource "proxmox_virtual_environment_file" "lxc_helpers" {
  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.node_name
  file_mode    = "0755"

  source_raw {
    data      = file("${path.module}/templates/helpers.sh")
    file_name = "lxc_helpers.sh"
  }
}

# LXC-specific init script (when custom scripts exist)
resource "proxmox_virtual_environment_file" "lxc_init_script" {
  count = length(var.custom_scripts) > 0 ? 1 : 0

  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.node_name
  file_mode    = "0755"

  source_raw {
    data = join("\n\n", [
      "#!/bin/bash",
      "# Custom initialization script for ${var.container_name}",
      "set -e",
      "source /tmp/lxc-helpers.sh",
      join("\n\n", local.custom_script_contents)
    ])
    file_name = "${var.container_id}-${var.container_name}-init.sh"
  }
}

# Hook script
resource "proxmox_virtual_environment_file" "lxc_hook_script" {
  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.node_name
  file_mode    = "0700"

  source_raw {
    data = templatefile("${path.module}/templates/hookscript.sh.tpl", {
      container_id           = var.container_id
      container_name         = var.container_name
      run_id                 = var.run_id
      has_init_script        = length(var.custom_scripts) > 0
      default_user           = var.default_user
      ssh_pub_key            = trimspace(var.ssh_public_key)
      ansible_ssh_pub_key    = trimspace(var.ansible_ssh_public_key)
      proxmox_ssh_pub_key    = trimspace(var.proxmox_ssh_public_key)
      hostname               = var.container_name
      packages               = join(" ", concat(["openssh-server", "sudo", "jq"], var.packages))
      mount_points           = var.mount_points
      generated_admin_password = var.generate_admin_password ? try(random_password.admin_password[0].result, "") : var.default_admin_password
      generated_user_password  = var.default_user_password
    })
    file_name = local.hook_file_name
  }

  lifecycle {
    ignore_changes = [
      source_raw.0.file_name
    ]
  }
}
