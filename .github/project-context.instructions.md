# Project Context for pve Repository

## Overview

This repository is for learning and implementing Infrastructure as Code (IaC) with OpenTofu(Terraform), Ansible, and Proxmox. 

## Infrastructure Setup

### Current Environment

- **pve-01**: Proxmox instance
- **HashiCorp Vault**: Running in Docker container on dedicated host (version 1.20.1)
- **Development Machine**: Laptop running Linux with Tofu and Ansible in Python virtual environment
- **SSH Keys**: Stored in vault as well as `~/.ssh/homelab/` for local development


## Current Project State

### Current Approach

- **SSH Key Automation**: 
  - **LXC**: Proxmox native SSH key injection for containers using `user_account.keys` array
  - **VM**: Standard provider approach with `user_account` + `user_data_file_id` separation for cloud-init
- **Hook Script Operations**: Terraform uses root@pam authentication for LXC hook script deployment and execution
- **Multi-Key Strategy**: All three SSH keys (proxmox_host, vm_deployment, ansible_management) automatically injected into containers and VMs
- **Container Initialization**: Hook scripts handle package installation, user creation, and service configuration
- **VM Initialization**: Standard cloud-init with provider-managed user accounts and custom package/script configuration
- **SSH Configuration**: Direct SSH access available immediately after container/VM creation without manual intervention
- **Vault Integration**: Both Ansible and Terraform retrieve API credentials and SSH keys from Vault
- **Secure Operations**: root@pam for hook scripts, terraform-prov for SSH host access, comprehensive SSH key coverage
- **Infrastructure as Code**: Full LXC container and VM lifecycle management via OpenTofu with JSON configuration files
- **Provider Compliance**: VM provisioning follows official bpg/proxmox provider documentation exactly

### Key Files and Configurations

#### Ansible Configuration

- **Virtual Environment**: `ansible/.venv/` with required dependencies
- **Inventory**: `ansible/inventory/hosts.ini`
- **Environment Variables**: `ansible/.env` (contains VAULT_TOKEN and VAULT_ADDR)
- **Main Playbooks**:
  - `ansible/vault_deploy.yml` - Vault deployment and container setup
  - `ansible/vault_post_install.yml` - Vault configuration and policy setup
  - `ansible/pve_setup.yml` - Proxmox post-install configuration
  - `ansible/store_proxmox_credentials.yml` - Store Proxmox API credentials in Vault
- **Global Variables**: `ansible/inventory/group_vars/all.yml`
- **Vault Variables**: `ansible/inventory/group_vars/vault.yml`
- **Host-specific Variables**: `ansible/inventory/group_vars/pve_01/vars.yml`

#### OpenTofu/Terraform Configuration

- **Main Configuration**: `tofu/main.tf` with module-based architecture
- **Vault Secrets Module**: `tofu/modules/vault-secrets/` for secure credential retrieval
- **LXC Module**: `tofu/modules/proxmox-lxc/` with automated SSH key injection and hook script management
- **VM Module**: `tofu/modules/proxmox-vm/` for traditional VM deployment (future use)
- **Container Configurations**: `tofu/config/lxcs/*.json` files for service-specific container definitions
- **Hook Scripts**: Automated container initialization with package installation and user setup
- **SSH Integration**: Native Proxmox SSH key injection with all three key types for comprehensive access

#### Vault Integration

- **KV Engines**: `ansible/` and `terraform/` paths in Vault
- **SSH Keys**: Generated during Vault initialization and stored at:
  - `terraform/ssh_keys/proxmox_host` - Terraform→Proxmox host access
  - `terraform/ssh_keys/vm_deployment` - VM/LXC cloud-init injection  
  - `terraform/ssh_keys/ansible_management` - Post-deployment configuration
- **API Credentials**: Stored at `terraform/api_credentials/{name}` with token_id and token_secret
- **Secrets Path**: `ansible/data/proxmox` (for initial admin credentials)
- **Authentication**: Root token accessed via environment variable
- **AppRole**: Configured for CI/CD automation (future use)
- **Deployment**: Docker container with persistent storage and init script

## Automation Strategy

### Authentication Flow

1. **Initial Setup**: Root/password authentication to Proxmox for initial user creation
2. **Vault SSH Key Generation**: Init script creates dedicated SSH keys for infrastructure
3. **SSH Key Deployment**: Deploy Vault-generated keys to Proxmox host for terraform-prov user
4. **Proxmox User Setup**: Create terraform-prov user with SSH access and API user with token
5. **API Token Storage**: Store generated API token in Vault for Terraform authentication
6. **LXC Deployment**: Terraform uses root@pam authentication for hook script operations
7. **Container Initialization**: Hook scripts deploy vm_deployment SSH keys and configure user access
8. **Configuration Management**: Ansible uses vm_deployment SSH keys for immediate post-deployment access

### Development Approach

- **SSH Key Management**: Vault-centric approach with purpose-specific key pairs
- **Privileged Operations**: root@pam authentication for hook script operations only
- **Provider Requirements**: Terraform proxmox provider configured for root@pam when hook scripts are required
- **User Model**: root@pam for hook scripts, terraform-prov for SSH host access, vm_deployment keys for container access
- **Implementation Status**: SSH key deployment, hook script authentication, container SSH setup, and Ansible integration operational

## Commands and Workflows

### Available Commands

The project uses a `justfile` for command automation in both `iac/ansible/` and `iac/tofu/` directories:
Run `just --list` in respective directory to see all available commands.


## Repository Structure

## Workflow Summary

### Complete Setup Process

1. **Deploy Vault**: `just vault-deploy` → Manual unseal → `just vault-configure`
2. **Setup Proxmox**: `just pve-setup` (creates users, SSH keys, API tokens)
3. **Store API Credentials**: `just store-proxmox-credentials` (saves tokens to Vault)
4. **Deploy Infrastructure**: `cd tofu && tofu plan && tofu apply`


### SSH Key Configuration Status

All containers have comprehensive SSH access with three key types:
- **vm_deployment**: Primary deployment and initial access
- **ansible_management**: Configuration management and automation
- **proxmox_host**: Host-level operations and troubleshooting

## Next Steps

3. **Ansible Configuration Management**: Implement post-deployment configuration with ansible_management keys
4. **VM Template Creation**: Extend automation to include VM deployment alongside LXC containers
5. **Monitoring Integration**: Add monitoring and logging for deployed services
6. **Backup Strategy**: Implement automated backup procedures for containers and configurations
