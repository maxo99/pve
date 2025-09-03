
locals {
  # Simple packages list for user_data (packages and scripts only)
  packages_list = join("\n", [for pkg in var.packages : "  - ${pkg}"])

  # Custom scripts for runcmd
  scripts_list = join("\n", [for script in var.custom_scripts : "  - ${script}"])

  # Generate password hash for cloud-init
  admin_password = var.generate_admin_password ? random_password.admin_password[0].result : var.default_admin_password

  # Complete cloud-init user data with proper user configuration
  user_data_content = templatefile("${path.module}/templates/standard-user-data.yml.tpl", {
    hostname       = var.vm_name
    admin_user     = var.default_user
    admin_password = local.admin_password
    ssh_public_key = trimspace(var.ssh_public_key)
    packages       = local.packages_list
    scripts        = local.scripts_list
  })
}


resource "proxmox_virtual_environment_file" "cloud_init_snippet" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name

  source_raw {
    data      = local.user_data_content
    file_name = "${var.vm_id}-${var.vm_name}-user-data.yml"
  }
}




