


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


