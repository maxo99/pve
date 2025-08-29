locals {
  # Genera configurazione custom per i pacchetti
  packages_cloud_init = templatefile("${path.module}/templates/custom-packages.yml.tpl", {
    packages = var.packages
    scripts  = var.custom_scripts
  })
  
  # Completa configurazione cloud-init usando la configurazione base dal parent
  cloud_init_content = templatefile("${path.module}/templates/combine.tpl", {
    base_config   = var.base_cloud_init
    hostname      = var.vm_name
    ssh_pub_key   = var.ssh_public_key
    default_user  = var.default_user
    custom_config = local.packages_cloud_init
  })
}

# Crea snippet cloud-init su Proxmox
resource "proxmox_virtual_environment_file" "cloud_init_snippet" {
  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.node_name
  
  source_raw {
    data = local.cloud_init_content
    file_name    = "${var.vm_id}-${var.vm_name}-cloud-init.yml"
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.vm_name
  node_name   = var.node_name
  vm_id       = var.vm_id
  description = var.description
  tags        = var.tags

  cpu {
    cores = var.cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory
  }

  # Configurazione del disco usando un'immagine cloud
  disk {
    datastore_id = var.datastore_id
    file_id      = var.cloud_image_id
    interface    = "virtio0"
    size         = var.disk_size
    iothread     = var.disk_iothread
  }
  
  # Configurazione di rete con MAC address personalizzato
  network_device {
    bridge      = var.network_bridge
    mac_address = var.mac_address
    model       = var.network_model
  }

  agent {
    enabled = true
    timeout = var.agent_timeout
  }

  operating_system {
    type = "l26" # Linux kernel 2.6+
  }

  # Usa lo snippet cloud-init
  initialization {
    datastore_id = var.datastore_id
    
    ip_config {
      ipv4 {
        address = var.ip_config.ipv4_address != "" ? var.ip_config.ipv4_address : "dhcp"
        gateway = var.ip_config.gateway != "" ? var.ip_config.gateway : null
      }
    }
    
    user_data_file_id = proxmox_virtual_environment_file.cloud_init_snippet.id
  }
  
  # Opzioni di avvio
  on_boot = var.start_on_boot
  started = true
}
