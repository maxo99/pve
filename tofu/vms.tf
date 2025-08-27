# # resource "proxmox_virtual_environment_vm" "cloudinit-example" {
# #   vm_id     = 310
# #   name      = "test-terraform0"
# #   node_name = "pve"

# #   # Comment out clone block since VM already exists
# #   clone {
# #     vm_id = 9333 # The name/ID of the template
# #     full  = true
# #   }


# #   # # Reduce timeouts to avoid long waits
# #   # timeout_create   = 600 # 10 minutes
# #   # timeout_start_vm = 600 # 10 minutes

# #   started         = true
# #   on_boot         = false # Don't require the VM to be bootable immediately
# #   stop_on_destroy = true

# #   efi_disk {
# #     datastore_id = "local-lvm"
# #     file_format  = "raw"
# #     type         = "4m"
# #   }

# #   agent {
# #     enabled = true
# #     timeout = "10m"
# #   }

# #   cpu {
# #     cores = 2
# #   }

# #   memory {
# #     dedicated = 1024
# #   }


# #   scsi_hardware = "virtio-scsi-pci"

# #   # Cloud-Init configuration
# #   initialization {
# #     ip_config {
# #       ipv4 {
# #         address = var.ci_ip_address
# #         gateway = var.ci_gateway
# #       }
# #       #   dynamic "ipv6" {
# #       #     for_each = var.ci_skip_ipv6 ? [] : [1]
# #       #     content {
# #       #       address = "dhcp"
# #       #     }
# #       #   }
# #     }
# #     # dns {
# #     #   servers = split(" ", var.ci_nameserver)
# #     # }
# #     user_account {
# #       username = var.ci_username
# #       password = var.ci_password
# #       keys     = [local.ci_ssh_keys]
# #     }
# #     vendor_data_file_id = "local:snippets/qemu-guest-agent.yml"
# #   }

# #   # Force VM to restart when IP configuration changes
# #   # reboot = true

# #   # Disk configuration
# #   disk {
# #     datastore_id = "local-lvm"
# #     interface    = "scsi0"
# #     size         = 4
# #   }

# #   # Network configuration
# #   network_device {
# #     bridge = "vmbr0"
# #     model  = "virtio"
# #   }

# #   boot_order = ["scsi0"]

# #   provisioner "local-exec" {
# #     command = <<EOT
# #       echo "Waiting for VM to be fully ready..."
      
# #       # Wait for SSH to be available and cloud-init to complete
# #       timeout 300 bash -c '
# #         while ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
# #           -i ${var.ssh_private_key_path} \
# #           ${var.ci_username}@${split("/", var.ci_ip_address)[0]} \
# #           "cloud-init status --wait" 2>/dev/null; do
# #           echo "Waiting for cloud-init to complete..."
# #           sleep 10
# #         done
# #       '
      
# #       echo "VM is ready, running Ansible..."
# #       ansible-playbook \
# #         -i inventory.ini \
# #         -u ${var.ci_username} \
# #         --private-key=${var.ssh_private_key_path} \
# #         ./playbooks/basic.yml
# #     EOT
# #   }
# # }

# resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
#   vm_id     = 501
#   name      = "test-ubuntu"
#   node_name = "pve"

#   agent {
#     enabled = true
#   }

#   cpu {
#     cores = 2
#   }

#   memory {
#     dedicated = 2048
#   }

#   disk {
#     datastore_id = "local-lvm"
#     file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
#     interface    = "virtio0"
#     iothread     = true
#     discard      = "on"
#     size         = 4
#   }

#   initialization {
#     ip_config {
#       ipv4 {
#         address = "192.168.6.170/22"
#         gateway = "192.168.4.1"
#       }
#     }
#     user_account {
#       username = var.ci_username
#       password = var.ci_password
#       keys     = [local.ci_ssh_keys]
#     }
#     user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config.id
#   }

#   network_device {
#     bridge = "vmbr0"
#     # model  = "virtio"
#   }

#     provisioner "local-exec" {
#     command = <<EOT
      
#       ansible-playbook \
#         -i inventory.ini \
#         ./playbooks/basic.yml
#     EOT
#   }

# }


# # output "vm_ipv4_address" {
# #   value = proxmox_virtual_environment_vm.ubuntu_vm.ipv4_addresses[1][0]
# # }
