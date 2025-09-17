
locals {
  # Read custom script files and prepare their content
  custom_script_contents = [
    for script_file in var.custom_scripts :
    file("${path.root}/config/lxcs/scripts/${script_file}")
  ]

  # Read helpers file content
  helpers_content = file("${path.module}/templates/helpers.sh")

  # Populate LXC init script template with variables
  init_script = templatefile("${path.module}/templates/init-script.sh.tpl", {
    default_user           = var.default_user
    ssh_pub_key            = trimspace(var.ssh_public_key)
    ansible_ssh_pub_key    = trimspace(var.ansible_ssh_public_key)
    proxmox_ssh_pub_key    = trimspace(var.proxmox_ssh_public_key)
    hostname               = var.container_name
    packages               = join(" ", concat(["openssh-server", "sudo", "jq"], var.packages))
    custom_script_contents = local.custom_script_contents
    generated_password     = var.generate_admin_password ? try(random_password.admin_password[0].result, "") : var.default_password
    mount_points           = var.mount_points
    run_id                 = var.run_id
    helpers_content        = local.helpers_content
  })

  # Populate monitoring script template
  monitor_script = templatefile("${path.module}/templates/monitor-hookscript.sh.tpl", {
    container_name        = var.container_name
    container_id          = var.container_id
    run_id               = var.run_id
    ssh_private_key_path = var.ssh_private_key_path
    proxmox_host_ip      = var.proxmox_host_ip
  })

  hook_file_name = "${var.container_id}-${var.container_name}-hook.sh"
}


# Create a Proxmox LXC hook script file
resource "proxmox_virtual_environment_file" "lxc_hook_script" {
  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.node_name
  file_mode    = "0700"

  source_raw {
    data      = local.init_script
    file_name = local.hook_file_name
  }


  lifecycle {
    ignore_changes = [
      # source_raw.0.data,  # Ignore content changes
      source_raw.0.file_name  # Ignore filename changes if using dynamic names
    ]
  }

}
