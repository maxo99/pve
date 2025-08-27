
# resource "random_password" "ubuntu_container_password" {
#   length           = 16
#   override_special = "_%@"
#   special          = true
# }

# resource "tls_private_key" "ubuntu_container_key" {
#   algorithm = "RSA"
#   rsa_bits  = 2048
# }

#   initialization {
#     hostname = "terraform-provider-proxmox-ubuntu-container"

#     ip_config {
#       ipv4 {
#         address = "dhcp"
#       }
#     }

#     user_account {
#       keys = [
#         trimspace(tls_private_key.ubuntu_container_key.public_key_openssh)
#       ]
#       password = random_password.ubuntu_container_password.result
#     }
#   }

# # # Run basic configuration - SSH is pre-installed in template
# # resource "ansible_playbook" "configure_docker_lxc_basic" {
# #   playbook   = "playbooks/basic.yml"
# #   name       = ansible_host.docker_lxc.name
# #   replayable = true

# #   extra_vars = {
# #     ansible_user                 = "root"
# #     ansible_ssh_private_key_file = var.ssh_private_key_path
# #   }

# #   depends_on = [ansible_host.docker_lxc]
# # }


# # # Install Docker after basic configuration
# # resource "ansible_playbook" "configure_docker_lxc_docker" {
# #   playbook   = "playbooks/docker.yml"
# #   name       = ansible_host.docker_lxc.name
# #   replayable = true

# #   extra_vars = {
# #     ansible_user                 = "root"
# #     ansible_ssh_private_key_file = var.ssh_private_key_path
# #   }

# #   depends_on = [ansible_playbook.configure_docker_lxc_basic]
# # }

# # # Configure SSH on the Docker LXC container using Ansible
# # resource "ansible_host" "docker_lxc" {
# #   name   = "192.168.6.152"
# #   groups = ["lxc_containers", "docker_hosts"]

# #   variables = {
# #     ansible_user                 = "root"
# #     ansible_ssh_private_key_file = var.ssh_private_key_path
# #     ansible_ssh_common_args      = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
# #     container_id                 = "401"
# #     proxmox_host                 = var.proxmox_host_ip
# #   }

# #   depends_on = [proxmox_virtual_environment_container.docker_example]
# # }



# // This is required as most LXC templates do not have SSH installed
# // and we need to install it to be able to run Ansible for further configuration
# resource "null_resource" "install_ssh" {
#   count      = var.install_ssh ? 1 : 0
#   depends_on = [proxmox_virtual_environment_container.debian_container]

#   provisioner "local-exec" {
#     command = <<-EOT
#       set -e
      
#       echo "Configuring network and installing SSH for LXC container ${proxmox_virtual_environment_container.debian_container.vm_id}..."
      
#       ssh ${var.proxmox_ssh} "pct exec ${proxmox_virtual_environment_container.debian_container.vm_id} -- /bin/bash -c '
#         export DEBIAN_FRONTEND=noninteractive
#         export LC_ALL=C.UTF-8
#         export LANG=C.UTF-8

#         # Configure network first
#         cat > /etc/network/interfaces << EOF
# auto lo
# iface lo inet loopback

# auto eth0
# iface eth0 inet static
#     address ${var.lxc1_ip_address}/22
#     gateway 192.168.4.1
#     dns-nameservers 192.168.4.1 8.8.8.8
#     dns-search local
# EOF

#         systemctl restart networking
#         sleep 5
#         ping -c 2 8.8.8.8 || exit 1

#         # Continue with SSH installation
#         echo \"en_US.UTF-8 UTF-8\" > /etc/locale.gen
#         locale-gen
#         update-locale LANG=en_US.UTF-8

#         apt-get update
#         apt-get install -y openssh-server
#         systemctl enable ssh
#         systemctl start ssh

#         sed -i \"s/#PermitRootLogin.*/PermitRootLogin yes/\" /etc/ssh/sshd_config
#         systemctl restart ssh
        
#         mkdir -p /root/.ssh
#         chmod 700 /root/.ssh

#         apt-get clean
#         apt-get autoremove -y
#       '"
#     EOT
#   }

#   triggers = {
#     container_id = proxmox_virtual_environment_container.debian_container.vm_id
#     ip_address   = var.lxc1_ip_address
#   }
# }


# # Create a Proxmox LXC hook script file
# resource "proxmox_virtual_environment_file" "lxc_hook_script" {
#   content_type = "snippets"
#   datastore_id = var.snippets_datastore_id
#   node_name    = var.node_name

#   file_mode    = "0700"
  
#   source_raw {
#     data      = local.init_script
#     file_name = local.hook_file_name
#   }
# }
#  hook_script_file_id = proxmox_virtual_environment_file.lxc_hook_script.id

  # ssh {
  #       agent=false
  #       private_key = file("~/.ssh/pve/root")
  # }

# data "local_file" "pve_private_key" {
#   filename = ".ssh/pve/root"
# }



# resource "proxmox_virtual_environment_file" "user_data_cloud_config" {
#   content_type = "snippets"
#   datastore_id = "local"
#   node_name    = "pve"

#   source_raw {
#     data = <<-EOF
#     #cloud-config
#     hostname: test-ubuntu
#     users:
#       - default
#       - name: ${var.ci_username}
#         password: ${var.ci_password}
#         groups:
#           - sudo
#         shell: /bin/bash
#         ssh_authorized_keys:
#           - ${local.ssh_public_key}
#         sudo: ALL=(ALL) NOPASSWD:ALL
#     runcmd:
#         - apt update
#         - apt install -y qemu-guest-agent net-tools
#         - timedatectl set-timezone America/New_York
#         - systemctl enable qemu-guest-agent
#         - systemctl start qemu-guest-agent
#         - echo 'export PS1="[\u@\h \W \$(date +%T)]\\$ "' >> /etc/bash.bashrc
#         - echo "done" > /tmp/cloud-config.done
#     EOF

#     file_name = "user-data-cloud-config.yaml"
#   }
# }


# resource "proxmox_virtual_environment_file" "cloud_init" {
#   #  for_each          = var.VM_CONFIG
#    node_name     = "pve"
#    content_type  = "snippets"
#    datastore_id   = "snippets"

#   #  source_raw {
#   #     data = templatefile("${path.module}/cloud-init-template.yaml", {
#   #        ENVIRONMENT = each.value.ENVIRONMENT
#   #     })
#   #     file_name = "/snippets/snippets/${each.value.ENVIRONMENT}-init.yaml"
#   #  }
# }
# locals {
#   ci_ssh_keys = trimspace(file("~/.ssh/pve/root.pub"))
#   ssh_public_key = data.local_file.ci_public_key.content
#   ssh_private_key = data.local_file.ci_private_key.content


#   # Scanning JSON configuration files for VMs and LXCs
#   # vm_files = fileset("${path.module}/config/vms/", "*.json")
#   lxc_files = fileset("${path.module}/config/lxcs/", "*.json")
  
#   # # Load JSON files and convert them to configuration maps
#   # vm_configs = {
#   #   for file in local.vm_files :
#   #     trimsuffix(basename(file), ".json") => jsondecode(file("${path.module}/config/vms/${file}"))
#   # }
  
#   lxc_configs = {
#     for file in local.lxc_files :
#       trimsuffix(basename(file), ".json") => jsondecode(file("${path.module}/config/lxcs/${file}"))
#   }

# }
