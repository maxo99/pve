resource "proxmox_virtual_environment_container" "example" {
  node_name = "pve"
  vm_id     = 400  # Different ID range from VMs
  
  # Container-specific settings
  unprivileged = true
  
  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
  }
  
  cpu {
    cores = 2
    units = 1024 
  }
  
  memory {
    dedicated = 1024
    swap      = 512
  }
  
  # Root filesystem
  disk {
    datastore_id = "local-lvm"
    size         = 8
  }
  
  # Network interface
  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }
  
  # Container initialization (different from cloud-init)
  initialization {
    hostname = "test-lxc"
    
    user_account {
      keys     = [local.ci_ssh_keys]
      password = var.ci_password
    }
    
    ip_config {
      ipv4 {
        address = "192.168.6.151/22"
        gateway = "192.168.4.1"
      }
    }
  }
  
  started = true
}
