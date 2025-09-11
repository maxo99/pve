locals {
  # VM type flags
  is_haos = var.vm_type == "haos"
  is_standard = var.vm_type == "standard"
  
  # HAOS-specific settings
  haos_settings = local.is_haos ? {
    bios          = "ovmf"
    machine       = "q35"
    disk_interface = "scsi0"
    scsi_hardware = "virtio-scsi-pci"
    boot_order    = ["scsi0"]
    os_type       = "l26"
    tablet        = false
    has_efi_disk  = true
    has_serial    = true
    ssd_flag      = true
  } : {
    bios          = null
    machine       = null
    disk_interface = "virtio0"
    scsi_hardware = null
    boot_order    = null
    os_type       = "other"
    tablet        = true
    has_efi_disk  = false
    has_serial    = false
    ssd_flag      = null
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.vm_name
  node_name = var.node_name
  vm_id     = var.vm_id
  
  description = var.description
  tags        = var.tags
  
  # Hardware settings
  started       = true
  bios          = local.haos_settings.bios
  machine       = local.haos_settings.machine
  on_boot       = var.start_on_boot
  scsi_hardware = local.haos_settings.scsi_hardware
  boot_order    = local.haos_settings.boot_order
  tablet_device = local.haos_settings.tablet

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
  }
  
  # EFI disk for HAOS VMs
  dynamic "efi_disk" {
    for_each = local.haos_settings.has_efi_disk ? [1] : []
    content {
      datastore_id = "local-lvm"
      file_format  = "raw"
      type         = "4m"
    }
  }

  disk {
    datastore_id = "local-lvm"
    import_from  = local.is_haos ? null : var.cloud_image_id
    file_id      = local.is_haos ? var.cloud_image_id : null
    interface    = local.haos_settings.disk_interface
    size         = var.disk_size
    iothread     = true
    discard      = "on"
    ssd          = local.haos_settings.ssd_flag
  }

  agent {
    enabled = true
  }

  # Cloud-init initialization for standard VMs only
  dynamic "initialization" {
    for_each = local.is_standard ? [1] : []
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
    bridge = "vmbr0"
  }
  
  # Operating system type
  operating_system {
    type = local.haos_settings.os_type
  }

  # Serial console for HAOS
  dynamic "serial_device" {
    for_each = local.haos_settings.has_serial ? [1] : []
    content {}
  }
}
