# Ansible Role: pve_add_users

This Ansible role automates user and SSH access management within a Proxmox VE environment. It creates a dedicated SSH user for Terraform/Ansible automation with optional Proxmox API access.

## Purpose

This role is designed to streamline the initial user and access control setup for a Proxmox VE server. It addresses the need for:

* **Enhanced Security:** Hardening SSH access by disabling password authentication and enforcing key-based login.
* **Automated Access:** Creating a dedicated SSH user for Terraform/Ansible automation with passwordless sudo access.
* **Vault Integration:** Using HashiCorp Vault-stored SSH keys for secure automation.
* **Flexible Access:** SSH-first approach with optional API access when needed.

## Tasks Performed

1. **Automation SSH User Creation:**
    * Creates a dedicated SSH user (`terraform-prov`) for automation access to the Proxmox host.
    * Configures SSH key-based authentication using Vault-stored keys.
    * Adds the user to sudo group with passwordless sudo access.
    * This user serves both Terraform and Ansible automation needs via SSH.

2. **Optional Proxmox API User Creation:**
    * Creates a Proxmox API user (`terraform-prov@pve`) for API-based operations.
    * Creates a dedicated Proxmox group for API access.
    * Generates API tokens for programmatic access when SSH is not sufficient.
    * Useful for operations requiring Proxmox API calls.

<!-- 3. **Admin User Creation (Optional - Currently Disabled):**
    * Creates a dedicated Proxmox Admin user via API.
    * Creates a dedicated Proxmox Admin group.
    * Adds the Admin user to the Admin group.
    * Assigns Administrator role to the Admin user group. -->

<!-- 3. **Authentik Realm Integration (Optional - Currently Disabled):**
    * Checks if an Authentik realm already exists in Proxmox.
    * Creates an Authentik realm in Proxmox if it doesn't exist, enabling OpenID Connect authentication. -->

3. **SSH Configuration:**
    * Ensures SSH key-based authentication is enabled.
    * Disables password-based authentication for SSH.
    * Restarts the SSH service to apply configuration changes.
    * Ensures the SSH service is enabled and running.

## Variables

### **Core SSH User Variables (Required)**

* **`pve_ansible_user_ssh`** (*Required*): SSH username for automation access. Default: `terraform-prov`. Defined in `group_vars/pve_01/vars.yml`.

### **Vault-Stored SSH Keys (Required)**

* **`proxmox_host_ssh_public_key`** (*Required*): Vault-stored SSH public key for Proxmox host access. Retrieved from `terraform/ssh_keys/proxmox_host:public_key`.

### **Optional API Access Variables**

* **`pve_ansible_user_api_realm`** (*Optional*): Proxmox API user with realm (e.g., `terraform-prov@pve`). Used if API access is needed. Defined in `group_vars/pve_01/vars.yml`.
* **`pve_ansible_token_id`** (*Optional*): API token identifier for programmatic access. Defined in `group_vars/pve_01/vars.yml`.
* **`pve_ansible_group`** (*Optional*): Proxmox group for API user permissions. Defined in `group_vars/pve_01/vars.yml`.

### **Legacy Variables (Currently Commented Out)**
<!-- * **`pve_root_user`** (*Legacy*): The root username for Proxmox. Bootstrap uses --ask-pass instead. -->
<!-- * **`pve_root_ssh_public_key_file`** (*Legacy*): Path to root SSH key file. Now using Vault-stored keys. -->
<!-- * **`pve_ansible_ssh_private_key_file`** (*Legacy*): Path to private SSH key file. Now using Vault-stored keys. -->
<!-- * **`pve_ansible_ssh_public_key_file`** (*Legacy*): Path to public SSH key file. Now using Vault-stored keys. -->
<!-- * **`api_token_file_path`** (*Legacy*): Path for generated API token storage. -->
<!-- * **`_pve_admin_user_realm`** (*Legacy*): Admin user variables removed for SSH-first approach. -->
<!-- * **`_pve_admin_password`** (*Legacy*): Admin password variables removed for SSH-first approach. -->

<!-- * **`pve_authentik_client_secret`** (*Required*): Client secret for Authentik integration. Fetched from Vault. Defined in `roles/pve_add_users/tasks/fetch_from_vault.yml`.
* **`pve_authentik_client_id`** (*Required*): Client ID for Authentik integration. Fetched from Vault. Defined in `roles/pve_add_users/tasks/fetch_from_vault.yml`.
* **`authentik_issuer_url`** (*Required*): URL of the Authentik issuer. Defined in `group_vars/all/vars`. -->

## Important Notes

* **SSH-First Approach:** This role prioritizes SSH access with passwordless sudo. API access is optional and only needed for specific Proxmox operations that require API calls.
* **Vault Integration:** SSH keys are stored and retrieved from HashiCorp Vault. Ensure Vault is configured and accessible with the required SSH keys at `terraform/ssh_keys/proxmox_host`.
* **Bootstrap Process:** Initial setup uses `--ask-pass` for root access. After role completion, all automation uses SSH key authentication.
* **No CI/CD Required:** This setup is optimized for direct development workflow without AppRole authentication or CI/CD pipelines.
* **Flexible Access Model:** SSH provides host-level access for file operations, while optional API access enables VM/container management operations.

## Dependencies

* `community.general` collection for SSH and user management modules
* `community.hashi_vault` collection for Vault integration (if using Vault-stored keys)
* HashiCorp Vault instance with SSH keys stored at required paths
