# Docker Stack Configurations

This directory contains Docker Compose stacks that can be deployed to various hosts.

## Usage

Deploy a stack to your Docker LXC container:

```bash
cd iac/ansible
ansible-playbook deploy_stack.yml -e "stack_name=example stack_path=config/stacks/example"
```

## Directory Structure

```
config/stacks/
├── example/
│   ├── docker-compose.yml
│   ├── setup.yml (optional - defines volumes/networks)
│   └── .env (optional)
├── monitoring/
│   └── docker-compose.yml
└── README.md
```

## Optional Setup Configuration

Create a `setup.yml` file in your stack directory to define Docker volumes and networks that should be created before deploying the stack:

```yaml
networks:
  - name: "my-network"
    driver: "bridge"
    ipam_config:
      - subnet: "172.20.0.0/16"

volumes:
  - name: "my-data"
    driver: "local"
    labels:
      backup: "true"
```

The setup configuration supports all Docker network and volume options. See the example stack for more details.

## Examples

### Deploy to specific host

```bash
ansible-playbook deploy_stack.yml -e "target_host=192.168.6.110 stack_name=monitoring stack_path=config/stacks/monitoring"
```

### Deploy to all docker hosts

```bash
ansible-playbook deploy_stack.yml -e "stack_name=example stack_path=config/stacks/example"
```

### Force update (ignore checksum)

```bash
ansible-playbook deploy_stack.yml -e "stack_name=example stack_path=config/stacks/example force_update=true"
```
