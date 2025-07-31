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