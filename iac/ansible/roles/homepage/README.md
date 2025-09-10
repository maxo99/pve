# Homepage Ansible Role

This role manages Homepage dashboard instances deployed via Terraform/OpenTofu. It provides configuration management, service control, and health monitoring for Homepage deployments.

## Features

- Configuration management using static YAML files
- Service lifecycle management (start/stop/restart)
- Health checks and validation
- Configuration backup and rollback
- Template-based dynamic configuration support
- Modular task organization with tags

## Quick Start

1. **Deploy Homepage configuration:**

   ```bash
   cd iac/ansible
   ansible-playbook homepage.yml
   ```

2. **Update only configuration files:**

   ```bash
   ansible-playbook homepage.yml --tags config
   ```

3. **Using the justfile for easier management:**

   ```bash
   cd iac/ansible
   just -f justfile-homepage deploy
   ```

## Configuration Files

Configuration files are stored in `iac/ansible/config/homepage/` and copied to the target system:

- `settings.yaml` - Homepage theme, layout, and general settings
- `services.yaml` - Service definitions and widgets
- `widgets.yaml` - Dashboard widgets configuration  
- `bookmarks.yaml` - Bookmark categories and links
- `docker.yaml` - Docker integration settings

## Directory Structure

```
roles/homepage/
├── defaults/main.yml          # Default variables
├── tasks/
│   ├── main.yml              # Main task orchestration
│   ├── validate.yml          # Input validation
│   ├── system.yml            # System preparation  
│   ├── config.yml            # Configuration management
│   ├── service.yml           # Service management
│   └── health_check.yml      # Health monitoring
├── templates/                # Jinja2 templates (if needed)
├── handlers/main.yml         # Service handlers
└── README.md

config/homepage/              # Static configuration files
├── settings.yaml
├── services.yaml  
├── widgets.yaml
├── bookmarks.yaml
└── docker.yaml
```

## Usage Examples

### Basic Deployment

```bash
ansible-playbook homepage.yml
```

### Configuration Only Updates  

```bash
ansible-playbook homepage.yml --tags config
```

### Service Management

```bash
ansible-playbook homepage.yml --tags service
```

### Health Checks

```bash
ansible-playbook homepage.yml --tags validate,health_check
```

### Using Justfile Commands

```bash
just -f justfile-homepage deploy      # Full deployment
just -f justfile-homepage config      # Config only
just -f justfile-homepage validate    # Health checks
just -f justfile-homepage ping        # Test connectivity
```

## Variables

Key variables (see `defaults/main.yml` for complete list):

- `homepage_manage_config: true` - Enable configuration management
- `homepage_port: 3000` - Service port
- `homepage_config_dir: /opt/homepage/config` - Configuration directory
- `homepage_health_check_enabled: true` - Enable health monitoring

## Host Configuration

Add homepage hosts to inventory:

```ini
[homepage]
192.168.6.100 ansible_user=root
```

Configure group variables in `inventory/group_vars/homepage/main.yml`

## Adding New Services

1. Edit `config/homepage/services.yaml`
2. Run: `ansible-playbook homepage.yml --tags config`
3. Services will be updated without full redeployment

## Tags

- `homepage` - All homepage tasks
- `validate` - Input validation  
- `system` - System preparation
- `config` - Configuration management
- `service` - Service management
- `health_check` - Health monitoring
- `info` - Display access information

## Features

- Configure homepage YAML files
- Manage homepage service
- Update homepage version
- Configure system settings
- Backup and restore configurations

## Variables

See `defaults/main.yml` for all available variables.

## Dependencies

- Node.js 22 LTS
- pnpm package manager
- systemd service management

## Example Playbook

```yaml
- hosts: homepage
  become: true
  roles:
    - role: homepage
      homepage_config:
        title: "My Dashboard"
        services:
          - name: "Proxmox"
            href: "https://pve-01:8006"
```

## Directory Structure

```text
/opt/homepage/
├── config/
│   ├── settings.yaml
│   ├── widgets.yaml
│   ├── services.yaml
│   ├── bookmarks.yaml
│   └── docker.yaml
├── .env
└── package.json
```
