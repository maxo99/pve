resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  node_name = var.node_name
  vm_id     = var.vm_id
  #
  description = var.description
  tags        = var.tags
  # bios          = "ovmf"
  # boot_order = ["scsi0"]
  # scsi_hardware = "virtio-scsi-pci"
  # on_boot = true
  # started = true

  # Standard lifecycle management
  # lifecycle {
  #   ignore_changes = [
  #     started
  #   ]
  # }

  cpu {
    cores = var.cores
    # type  = var.cpu_type
  }

  memory {
    dedicated = var.memory
  }
  # efi_disk {
  #   datastore_id = "local-lvm"
  #   file_format  = "raw"
  #   type         = "4m"
  # }

  disk {
    # datastore_id = var.datastore_id
    datastore_id = "local-lvm"
    import_from  = var.cloud_image_id
    interface    = "virtio0"
    size         = 6
    iothread     = true
    discard      = "on"
  }



  agent {
    enabled = true
    # timeout = var.agent_timeout # Use configurable timeout
    # trim    = true              # Enable TRIM support for better disk performance
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_snippet.id

  }

  network_device {
    # bridge      = var.network_bridge
    # mac_address = var.mac_address
    bridge = "vmbr0"
    # model  = "virtio"
  }
  # operating_system {
  #   type = "l26" # Linux kernel 2.6+
  # }

  # serial_device {}

}
