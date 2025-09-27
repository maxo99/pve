
locals {

  hook_file_name = "${var.container_id}-${var.container_name}-hook.sh"
  # Read custom script files and prepare their content
  custom_script_contents = [
    for script_file in var.custom_scripts :
    file("${var.config_path}/lxcs/hookscripts/${script_file}")
  ]

  # Parse mapping lists of form "src:dest"
  pre_conf_mappings = [
    for mapping in var.pre_confs : {
      src  = trimspace(split(":", mapping)[0])
      dest = trimspace(split(":", mapping)[1])
    }
  ]

  post_conf_mappings = [
    for mapping in var.post_confs : {
      src  = trimspace(split(":", mapping)[0])
      dest = trimspace(split(":", mapping)[1])
    }
  ]

  # Back-compat: if legacy var.confs is used and pre/post are empty, treat all as post-install
  legacy_conf_mappings = [
    for mapping in var.confs : {
      src  = trimspace(split(":", mapping)[0])
      dest = trimspace(split(":", mapping)[1])
    }
  ]

  effective_pre_conf_mappings  = length(local.pre_conf_mappings) > 0 ? local.pre_conf_mappings : []
  effective_post_conf_mappings = length(local.post_conf_mappings) > 0 ? local.post_conf_mappings : local.legacy_conf_mappings
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
      container_id             = var.container_id
      container_name           = var.container_name
      run_id                   = var.run_id
      has_init_script          = length(var.custom_scripts) > 0
      default_user             = var.default_user
      ssh_pub_key              = trimspace(var.ssh_public_key)
      ansible_ssh_pub_key      = trimspace(var.ansible_ssh_public_key)
      proxmox_ssh_pub_key      = trimspace(var.proxmox_ssh_public_key)
      hostname                 = var.container_name
      packages                 = join(" ", concat(["openssh-server", "sudo", "jq"], var.packages))
      mount_points             = var.mount_points
  pre_conf_files           = local.effective_pre_conf_mappings
  post_conf_files          = local.effective_post_conf_mappings
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

# Upload each pre/post conf source file as a snippet for later copying into the container
resource "proxmox_virtual_environment_file" "lxc_conf_files" {
  for_each     = merge(
    { for m in local.effective_pre_conf_mappings : m.src => m },
    { for m in local.effective_post_conf_mappings : m.src => m }
  )
  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.node_name
  file_mode    = "0644"

  source_raw {
    # read from config repo path
    data      = file("${var.config_path}${each.value.src}")
    file_name = "${var.container_id}-${var.container_name}-${replace(basename(each.value.src), ".", "_")}"
  }
}
