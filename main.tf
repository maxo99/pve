resource "proxmox_virtual_environment_vm" "cloudinit-example" {
  node_name = "pve"
  vm_id     = 300
  name      = "test-terraform0"

  # Reduce timeouts to avoid long waits
  timeout_create   = 300 # 5 minutes
  timeout_start_vm = 300 # 5 minutes

  started = true
  on_boot = false # Don't require the VM to be bootable immediately

  agent {
    enabled = true
    timeout = "5m" # Reduce timeout to avoid long waits
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 1024
  }

  clone {
    vm_id = 9000 # The name/ID of the template
    full  = true
  }

  scsi_hardware = "virtio-scsi-single"

  # Cloud-Init configuration
  initialization {
    ip_config {
      ipv4 {
        address = var.ci_ip_address
        gateway = var.ci_gateway
      }
      dynamic "ipv6" {
        for_each = var.ci_skip_ipv6 ? [] : [1]
        content {
          address = "dhcp"
        }
      }
    }
    # dns {
    #   servers = split(" ", var.ci_nameserver)
    # }
    user_account {
      username = var.ci_username
      password = var.ci_password
      keys     = [local.ci_ssh_keys]
    }
    vendor_data_file_id = "local:snippets/qemu-guest-agent.yml"
  }

  # Force VM to restart when IP configuration changes
  reboot = true

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 3
  }

  # Network configuration
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  boot_order = ["scsi0"]

  provisioner "local-exec" {
    command = <<EOT
      ansible-playbook -i inventory.ini -u ${var.ci_username} --private-key=${var.ssh_private_key_path} ./playbooks/basic.yml
    EOT
  }

}

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.60.0"
    }
  }
}




provider "proxmox" {
  endpoint = var.proxmox_api_url
  username = var.proxmox_user
  password = var.proxmox_password
  insecure = true # Set to false if you have valid SSL certificates
}
