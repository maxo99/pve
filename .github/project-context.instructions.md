# Project Context for hashi_vault_test Repository

## Overview

This repository is for learning and implementing Infrastructure as Code (IaC) with Terraform/OpenTofu, Ansible, and Proxmox. The goal is to create a fully automated Proxmox homelab setup with proper user management and SSH key automation using HashiCorp Vault.

## Infrastructure Setup

### Current Environment

- **Proxmox VE**: Newly deployed instance
- **HashiCorp Vault**: Running in Docker container on dedicated host (version 1.20.1)
- **Development Machine**: Laptop running Linux with Ansible in Python virtual environment
- **SSH Keys**: Stored in `~/.ssh/homelab/` directory structure for laptop-based development

### Network Configuration

Network details, DNS servers, domain, and timezone are configured in `ansible/inventory/group_vars/all.yml`. Host-specific configurations are in `ansible/inventory/hosts.ini` and respective group_vars directories.

## Current Project State

### Completed Tasks

- ✅ HashiCorp Vault deployment via Docker and Ansible automation
- ✅ Vault initialization, unsealing, and post-install configuration
- ✅ Vault KV v2 engines enabled at `ansible/` and `terraform/` paths
- ✅ Vault AppRole authentication configured for CI/CD workflows
- ✅ SSH key generation and storage in Vault KV engine at `terraform/ssh_keys/` paths:
  - `terraform/ssh_keys/proxmox_host` - For Terraform to connect to Proxmox host
  - `terraform/ssh_keys/vm_deployment` - For VM/LXC deployment via cloud-init
  - `terraform/ssh_keys/ansible_management` - For post-deployment configuration management
- ✅ Ansible virtual environment setup with required dependencies
- ✅ Basic Proxmox post-install configuration (repositories, packages, DNS, fail2ban)
- ✅ Vault secrets storage and retrieval integration
- ✅ SSH user creation (terraform-prov) on Proxmox host with API user configuration
- ✅ SSH key deployment task created (`ansible/tasks/push_ssh_key/`) with parameterized key types
- ✅ SSH key deployment integrated into `pve_setup.yml` playbook
- ✅ Terraform provider configured for API token authentication (bpg/proxmox)
- ✅ Vault-secrets module updated to retrieve SSH keys and API credentials from Vault
- ✅ Proxmox API token generation and storage automation
- ✅ API credential storage in Vault via dedicated playbook
- ✅ **LXC Container Infrastructure**: Full automation of LXC container deployment with SSH key integration
- ✅ **SSH Automation Achievement**: Complete SSH key automation for LXC containers without manual intervention
- ✅ **Container Templates**: Working LXC configurations for PostgreSQL, Redis, and Homepage Dashboard
- ✅ **Hook Script Automation**: Automated package installation and user configuration via Proxmox hook scripts
- ✅ **Multi-key SSH Access**: All three SSH keys (VM deployment, Ansible management, Proxmox host) automatically configured in containers
- ✅ **SSH Investigation Tools**: Comprehensive justfile commands for SSH debugging and troubleshooting
- ✅ **VM Infrastructure**: Standard Proxmox provider approach for VM deployment with proper cloud-init and guest agent integration
- ✅ **VM SSH Automation**: Working SSH key injection and cloud-init configuration following provider best practices
- ✅ **VM Template System**: JSON-based VM configuration system with packages and custom script support

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
- **Current Infrastructure**: 
  - Homepage Dashboard (homer) at 192.168.5.39:3000
  - PostgreSQL Database at 192.168.5.41
  - Redis Cache Server at 192.168.5.49
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

### Environment Setup

```bash
cd ansible/
uv sync
source .venv/bin/activate
```

### Available Commands

The project uses a `justfile` for command automation in both `ansible/` and `tofu/` directories:

#### Ansible Commands (`ansible/` directory)
Run `just --list` to see all available Ansible automation commands.

#### OpenTofu Commands (`tofu/` directory)
- **Infrastructure Management**: `just plan`, `just apply`, `just destroy`
- **Container Operations**: `just plan-lxc <name>`, `just apply-lxc <name>`, `just destroy-lxc <name>`
- **SSH Testing & Debugging**:
  - `just test-ssh` - Test SSH access to all containers
  - `just check-ssh-keys` - Verify SSH key configuration across infrastructure
  - `just debug-ssh <name>` - Detailed SSH debugging for specific container
  - `just fix-ssh <name>` - Emergency SSH key repair for container
- **Infrastructure Status**: `just get-ips`, `just debug-containers`, `just output`
- **Development**: `just validate`, `just fmt`, `just init`, `just clean`

## Repository Structure

The main components are organized under the `ansible/` directory with playbooks, roles, and inventory configuration. Use standard file system tools or your editor to explore the current structure.

## Known Issues and Resolutions

## Known Issues and Resolutions

### LXC SSH Key Automation (RESOLVED ✅)

- **Issue**: Initial attempts to manage SSH keys via hook scripts failed due to cloud-init misconceptions and timing issues
- **Root Cause**: LXC containers don't use cloud-init; Proxmox has native SSH key injection via `user_account.keys`
- **Solution**: Implemented Proxmox native SSH key injection using `initialization.user_account.keys` array with all three key types
- **Result**: Complete SSH automation achieved - containers accessible immediately after creation without manual intervention

### Hook Script Execution and Permissions (RESOLVED ✅)

- **Issue**: Hook scripts failed to execute due to permission and timing issues
- **Solution**: Implemented local-exec provisioner to set executable permissions on hook scripts after upload
- **Current Status**: Hook scripts execute successfully for package installation and user configuration

### Container Network Configuration (PARTIAL ISSUE ⚠️)

- **Issue**: Redis container receiving dual IP addresses (192.168.5.49 and 192.168.5.50) from DHCP
- **Root Cause**: Network restart during container lifecycle causing secondary IP assignment
- **Workaround**: Modified justfile IP detection to use first/primary IP address only
- **Future Solution**: Consider implementing static IP configuration for containers

## Workflow Summary

### Complete Setup Process

1. **Deploy Vault**: `just vault-deploy` → Manual unseal → `just vault-configure`
2. **Setup Proxmox**: `just pve-setup` (creates users, SSH keys, API tokens)
3. **Store API Credentials**: `just store-proxmox-credentials` (saves tokens to Vault)
4. **Deploy Infrastructure**: `cd tofu && tofu plan && tofu apply`

### Complete Setup Process

1. **Deploy Vault**: `just vault-deploy` → Manual unseal → `just vault-configure`
2. **Setup Proxmox**: `just pve-setup` (creates users, SSH keys, API tokens)
3. **Store API Credentials**: `just store-proxmox-credentials` (saves tokens to Vault)
4. **Deploy Infrastructure**: `cd tofu && tofu plan && tofu apply`
5. **Verify SSH Access**: `just test-ssh` (validates SSH automation)
6. **Access Services**:
   - Homepage Dashboard: http://192.168.5.39:3000
   - PostgreSQL: `psql -h 192.168.5.41 -U postgres`
   - Redis: `redis-cli -h 192.168.5.49`

## Current Infrastructure Status

### Active LXC Containers

- **Homepage Dashboard (ID: 2005)**: Homer dashboard at 192.168.5.39:3000 - ✅ SSH Working
- **PostgreSQL Database (ID: 2006)**: Database server at 192.168.5.41 - ✅ SSH Working  
- **Redis Cache Server (ID: 2007)**: Cache server at 192.168.5.49 - ✅ SSH Working (dual IP resolved)

### SSH Key Configuration Status

All containers have comprehensive SSH access with three key types:
- **vm_deployment**: Primary deployment and initial access
- **ansible_management**: Configuration management and automation
- **proxmox_host**: Host-level operations and troubleshooting

## Next Steps

1. **Static IP Implementation**: Configure static IP addresses for containers to resolve DHCP dual-IP issues
2. **Service Integration**: Connect services (Homepage → PostgreSQL, Redis caching)
3. **Ansible Configuration Management**: Implement post-deployment configuration with ansible_management keys
4. **VM Template Creation**: Extend automation to include VM deployment alongside LXC containers
5. **Monitoring Integration**: Add monitoring and logging for deployed services
6. **Backup Strategy**: Implement automated backup procedures for containers and configurations
