resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  node_name = var.node_name
  vm_id     = var.vm_id
  
  description = var.description
  tags        = var.tags
  
  # HAOS-specific settings
  bios          = var.vm_type == "haos" ? "ovmf" : null
  machine       = var.vm_type == "haos" ? "q35" : null
  on_boot       = var.start_on_boot
  started       = true

  cpu {
    cores = var.cores
    # type  = var.cpu_type
  }

  memory {
    dedicated = var.memory
  }
  
  # EFI disk for HAOS VMs
  dynamic "efi_disk" {
    for_each = var.vm_type == "haos" ? [1] : []
    content {
      datastore_id = "local-lvm"
      file_format  = "raw"
      type         = "4m"
    }
  }

  disk {
    # datastore_id = var.datastore_id
    datastore_id = "local-lvm"
    import_from  = var.vm_type == "haos" ? null : var.cloud_image_id
    file_id      = var.vm_type == "haos" ? var.cloud_image_id : null
    interface    = var.vm_type == "haos" ? "scsi0" : "virtio0"
    size         = var.disk_size
    iothread     = true
    discard      = "on"
    ssd          = var.vm_type == "haos" ? true : null
  }

  agent {
    enabled = true
    # timeout = var.agent_timeout # Use configurable timeout
    # trim    = true              # Enable TRIM support for better disk performance
  }

  # Only add cloud-init initialization for standard VMs
  dynamic "initialization" {
    for_each = var.vm_type == "standard" ? [1] : []
    content {
      ip_config {
        ipv4 {
          address = var.ip_config.ipv4_address == "dhcp" ? "dhcp" : var.ip_config.ipv4_address
          gateway = var.ip_config.gateway != "" ? var.ip_config.gateway : null
        }
      }
      user_data_file_id = proxmox_virtual_environment_file.cloud_init_snippet[0].id
    }
  }

  network_device {
    # bridge      = var.network_bridge
    # mac_address = var.mac_address
    bridge = "vmbr0"
    # model  = "virtio"
  }
  
  # Operating system type
  operating_system {
    type = var.vm_type == "haos" ? "l26" : "other"
  }

  # Serial console for HAOS
  dynamic "serial_device" {
    for_each = var.vm_type == "haos" ? [1] : []
    content {}
  }
  
  # Tablet device settings
  tablet_device = var.vm_type == "haos" ? false : true
  
  # SCSI hardware for HAOS
  scsi_hardware = var.vm_type == "haos" ? "virtio-scsi-pci" : null
  boot_order    = var.vm_type == "haos" ? ["scsi0"] : null
}
