resource "proxmox_virtual_environment_vm" "cloudinit-example" {
  node_name = "pve"
  vm_id     = 310
  name      = "test-terraform0"

  # Comment out clone block since VM already exists
  clone {
    vm_id = 9333 # The name/ID of the template
    full  = true
  }


  # Reduce timeouts to avoid long waits
  timeout_create   = 600 # 10 minutes
  timeout_start_vm = 600 # 10 minutes

  started = true
  on_boot = false # Don't require the VM to be bootable immediately
  stop_on_destroy = true

  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }

  agent {
    enabled = true
    timeout = "10m"
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 1024
  }


  scsi_hardware = "virtio-scsi-pci"

  # Cloud-Init configuration
  initialization {
    ip_config {
      ipv4 {
        address = var.ci_ip_address
        gateway = var.ci_gateway
      }
      #   dynamic "ipv6" {
      #     for_each = var.ci_skip_ipv6 ? [] : [1]
      #     content {
      #       address = "dhcp"
      #     }
      #   }
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
  # reboot = true

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 4
  }

  # Network configuration
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  boot_order = ["scsi0"]

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for VM to be fully ready..."
      
      # Wait for SSH to be available and cloud-init to complete
      timeout 300 bash -c '
        while ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
          -i ${var.ssh_private_key_path} \
          ${var.ci_username}@${split("/", var.ci_ip_address)[0]} \
          "cloud-init status --wait" 2>/dev/null; do
          echo "Waiting for cloud-init to complete..."
          sleep 10
        done
      '
      
      echo "VM is ready, running Ansible..."
      ansible-playbook \
        -i inventory.ini \
        -u ${var.ci_username} \
        --private-key=${var.ssh_private_key_path} \
        ./playbooks/basic.yml
    EOT
  }
}
