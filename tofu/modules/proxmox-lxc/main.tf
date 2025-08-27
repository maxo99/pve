locals {
  # Populate LXC init script template with variables
  init_script = templatefile("${path.module}/templates/init-script.sh.tpl", {
    default_user         = var.default_user
    ssh_pub_key          = var.ssh_public_key
    ansible_ssh_pub_key  = var.ansible_ssh_public_key
    proxmox_ssh_pub_key  = var.proxmox_ssh_public_key
    hostname             = var.container_name
    packages             = join(" ", var.packages)
    custom_scripts       = var.custom_scripts
  })

  hook_file_name = "${var.container_id}-${var.container_name}-hook.sh"
}

# Create a Proxmox LXC hook script file
resource "proxmox_virtual_environment_file" "lxc_hook_script" {
  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.node_name

  source_raw {
    data      = local.init_script
    file_name = local.hook_file_name
  }

  # Use a provisioner to make the script executable via SSH as root@pam
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_private_key_path} root@${var.proxmox_host_ip} 'chmod +x /var/lib/vz/snippets/${local.hook_file_name}'"
  }
}

resource "proxmox_virtual_environment_container" "lxc" {
  node_name   = var.node_name
  vm_id       = var.container_id
  description = var.description
  tags        = var.tags

  # Container type configuration
  operating_system {
    template_file_id = var.template_id != null ? var.template_id : var.ostemplate_url
    type             = "ubuntu"   # or the appropriate type
  }
  
  # Hook script for container initialization (requires root@pam authentication)
  hook_script_file_id = proxmox_virtual_environment_file.lxc_hook_script.id
  
  # Risorse
  cpu {
    cores        = var.cores
    architecture = var.cpu_architecture
  }

  memory {
    dedicated = var.memory
    swap      = var.swap_memory
  }

  # Disk configuration
  disk {
    datastore_id = var.datastore_id
    size         = var.disk_size
  }
  
  # Network configuration with custom MAC address
  network_interface {
    name        = "eth0"
    bridge      = var.network_bridge
    # mac_address = var.mac_address
    # firewall    = var.firewall
  }

  # Initial container configuration
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
      keys     = [
        var.ssh_public_key,
        var.ansible_ssh_public_key, 
        var.proxmox_ssh_public_key
      ]
      password = var.root_password
    }
  }
  
  features {
    fuse    = var.feature_fuse
    keyctl  = var.feature_keyctl
    nesting = var.feature_nesting
  }

  # Automatic start/shutdown options
  start_on_boot = var.start_on_boot
  unprivileged  = var.unprivileged
  started       = true
}
