# justfile

set dotenv-load

# Default recipe to show available commands
default:
	@just --list

remove_state:
	tofu state rm proxmox_virtual_environment_vm.cloudinit-example

# Create a new SSH key for Cloud-Init
create_ssh_key:
	@echo "Creating SSH key for Cloud-Init..."
	mkdir -p ~/.ssh/pve
	ssh-keygen -t ed25519 -f ~/.ssh/pve/cloud-init -C "Cloud-Init@Terraform"


test-ansible:
	ansible-playbook -i 192.168.6.150, -u root --private-key=~/.ssh/pve/cloud-init ./playbooks/basic.yml

# Remove SSH host key for VM (useful after VM recreation)
clear-ssh-host-key:
	ssh-keygen -f ~/.ssh/known_hosts -R 192.168.6.150

# Test ansible with inventory file
test-ansible-inventory:
	ansible-playbook -i inventory.ini -u root --private-key=~/.ssh/pve/cloud-init ./playbooks/basic.yml

# Complete workflow: clear host key, then run ansible
ansible-fresh:
	just clear-ssh-host-key
	sleep 2
	just test-ansible-inventory