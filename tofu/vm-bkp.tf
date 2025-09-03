# resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
#   content_type = "snippets"
#   datastore_id = "local"
#   node_name    = "pve-01"

#   source_raw {
#     data = <<-EOF
#     #cloud-config
#     hostname: test-ubuntu
#     timezone: America/New_York
#     users:
#       - default
#       - name: ubuntu
#         password: ${var.ci_password}
#         groups:
#           - sudo
#         shell: /bin/bash
#         ssh_authorized_keys:
#           - ${trimspace(local.ssh_public_key)}
#         sudo: ALL=(ALL) NOPASSWD:ALL
#     # bootcmd:
#     #     - systemctl enable qemu-guest-agent
#     #     - systemctl start qemu-guest-agent
#     chpasswd:
#       list: |
#         ubuntu:password123
#     packages:
#       - qemu-guest-agent
#       - net-tools
#       - curl
#     runcmd:
#         # - apt update
#         # - apt install -y qemu-guest-agent net-tools
#         # - timedatectl set-timezone America/New_York
#         - systemctl enable qemu-guest-agent
#         - systemctl start qemu-guest-agent
#         # - echo 'export PS1="[\u@\h \W \$(date +%T)]\\$ "' >> /etc/bash.bashrc
#         - echo "done" > /tmp/cloud-config.done
#     EOF

#     file_name = "user-data-cloud-config.yml"
#   }
# }

# resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
#   name      = "test-ubuntu"
#   node_name = "pve-01"
#   vm_id     = 102

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
#     import_from  = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
#     interface    = "virtio0"
#     iothread     = true
#     discard      = "on"
#     size         = 20
#   }

#   initialization {
#     ip_config {
#       ipv4 {
#         address = "dhcp"
#       }
#     }
#     user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config.id
#   }
#   network_device {
#     bridge = "vmbr0"
#   }

# }
#####################################################################################

# resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
#   content_type = "import"
#   datastore_id = "local"
#   node_name    = "pve-01"
#   url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
#   # need to rename the file to *.qcow2 to indicate the actual file format for import
#   file_name = "jammy-server-cloudimg-amd64.qcow2"
# }

# output "vm_ipv4_address" {
#   value = proxmox_virtual_environment_vm.ubuntu_vm.ipv4_addresses[1][0]
# }






# resource "proxmox_virtual_environment_vm" "cloudinit-example" {
#   depends_on = [proxmox_virtual_environment_file.user_data_cloud_config]

#   vm_id           = 172
#   name            = "test-terraform0"
#   node_name       = "pve-01"
#   # started         = true
#   # reboot          = true
#   on_boot         = true
#   stop_on_destroy = true
#   scsi_hardware   = "virtio-scsi-pci"
#   boot_order      = ["scsi0"]

#   clone {
#     # vm_id = 100
#     vm_id = 52007
#     # full  = true
#     datastore_id = "local-lvm"
#   }

#   agent {
#     enabled = true
#     # trim    = true
#     timeout = "5m"
#   }

#   # cpu {
#   #   cores = 2
#   # }

#   cpu {
#     cores = 2
#   }

#   # memory {
#   #   dedicated = 1024
#   # }

#   memory {
#     dedicated = 2048
#   }



#   # disk {
#   #   datastore_id = "local-lvm"
#   #   # interface    = "scsi0"
#   #   interface    = "ide2"

#   #   size         = 6
#   #   discard      = "on"
#   #   ssd          = true
#   #   file_id      = "cloudinit"

#   # }

#   efi_disk {
#     datastore_id = "local-lvm"
#     file_format  = "raw"
#     type         = "4m"
#     # pre_enrolled_keys = true # Helps with secure boot configuration
#   }


#   # network_device {
#   #   bridge = "vmbr0"
#   #   model  = "virtio"
#   # }

#   network_device {
#     bridge = "vmbr0"
#     model  = "virtio"
#   }
#   initialization {
#     ip_config {
#       ipv4 {
#         address = "dhcp"
#         gateway = var.ci_gateway
#       }
#     }
#     user_account {
#       username = var.ci_username
#       password = var.ci_password
#       keys     = [local.ssh_public_key]
#     }
#     # vendor_data_file_id = "local:snippets/user-data-cloud-config.yml"
#     # user_data_file_id   = "local:snippets/user-data-cloud-config.yml"
#     # meta_data_file_id   = "local:snippets/user-data-cloud-config.yml"
#   }



#   # provisioner "local-exec" {
#   #   command = <<EOT
#   #     echo "Waiting for VM to be fully ready..."

#   #     # Wait for SSH to be available and cloud-init to complete
#   #     timeout 300 bash -c '
#   #       while ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
#   #         -i ${var.ssh_private_key_path} \
#   #         ${var.ci_username}@${split("/", var.ci_ip_address)[0]} \
#   #         "cloud-init status --wait" 2>/dev/null; do
#   #         echo "Waiting for cloud-init to complete..."
#   #         sleep 10
#   #       done
#   #     '

#   #     echo "VM is ready, running Ansible..."
#   #     ansible-playbook \
#   #       -i inventory.ini \
#   #       -u ${var.ci_username} \
#   #       --private-key=${var.ssh_private_key_path} \
#   #       ./playbooks/basic.yml
#   #   EOT
#   # }
# }

# resource "proxmox_virtual_environment_vm" "ubuntu_vm" {
#   vm_id     = 501
#   name      = "test-ubuntu"
#   node_name = "pve-01"

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
#       keys     = [local.ssh_public_key]
#     }
#     # user_data_file_id = proxmox_virtual_environment_file.user_data_cloud_config.id
#   }

#   network_device {
#     bridge = "vmbr0"
#     # model  = "virtio"
#   }

#   provisioner "local-exec" {
#     command = <<EOT

#       ansible-playbook \
#         -i inventory.ini \
#         ./playbooks/basic.yml
#     EOT
#   }

# }


