# resource "tls_private_key" "ubuntu_container_key" {
#   algorithm = "RSA"
#   rsa_bits  = 2048
# }



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


