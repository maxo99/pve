# Frigate NVR Setup Documentation

## Overview

Frigate NVR (Network Video Recorder) has been successfully deployed in LXC container 111 using Infrastructure as Code (OpenTofu + Ansible). The system includes camera integration, GPU passthrough for future hardware acceleration, and automated configuration management.

## Current Configuration

### Infrastructure

- **Container**: LXC 111 (frigate) on pve-01
- **OS**: Debian 12 (unprivileged: false, nesting: true)
- **Resources**: 8GB RAM, 4 CPU cores, 32GB disk
- **Network**: 192.168.6.111/22 (static IP)
- **Storage**: `/tank` mounted for media storage
- **GPU Passthrough**: Intel HD Graphics 500 (`/dev/dri/card1`, `/dev/dri/renderD128`)

### Deployment Method

- **OpenTofu**: Container provisioning with GPU passthrough
- **Ansible**: Configuration management (Frigate config, Docker Compose)
- **Docker**: Frigate v0.14.1 running in container

### Camera Setup

- **Camera**: Amcrest IP camera at 192.168.6.129
- **Credentials**: admin/{PASSWORD} (RTSP access)
- **Stream**: go2rtc restreaming via `rtsp://127.0.0.1:8554/front1-sub`
- **Detection**: CPU-based (3 threads) - hardware acceleration prepared but not active

## Verification Methods

### Basic Health Checks

```bash
# Check container status
ssh root@192.168.6.111 "docker ps"

# Check Frigate logs
ssh root@192.168.6.111 "docker logs --tail 20 frigate"

# Verify GPU devices available
ssh root@192.168.6.111 "ls -la /dev/dri/ && vainfo"

# Check go2rtc stream configuration
ssh root@192.168.6.111 "docker exec frigate cat /dev/shm/go2rtc.yaml"
```

### Web Interface Access

- **Frigate UI**: <http://192.168.6.111:5000>
- **go2rtc**: <http://192.168.6.111:1984> (embedded in Frigate)

### Configuration Verification

```bash
# View current Frigate configuration
ssh root@192.168.6.111 "cat /etc/frigate/config.yml"

# Check camera detection status
ssh root@192.168.6.111 "docker logs frigate 2>&1 | grep -E 'front1|detector|fps'"
```

### Ansible Management

```bash
cd /home/maxo/code/pve/iac/ansible

# Check configuration differences
ansible-playbook frigate.yml -l frigate --check --diff

# Apply configuration changes
ansible-playbook frigate.yml -l frigate
```

## File Locations

### Configuration Files

- **OpenTofu Config**: `iac/config/meta.yml` (gpu_passthrough: true)
- **Ansible Config**: `iac/ansible/inventory/group_vars/frigate/main.yml`
- **Frigate Template**: `iac/ansible/roles/frigate/templates/config.yml.j2`
- **Container Config**: `/etc/frigate/config.yml` (on container)
- **Docker Compose**: `/opt/frigate/docker-compose.yml` (on container)

### Debug Tools

- **Justfile recipes**: `iac/ansible/justfile` (frigate-* commands)
- **Debug bundle**: `just frigate-debug-bundle` (creates timestamped diagnostic file)

## Next Steps

### 1. Hardware Acceleration (Optional)

Enable Intel QuickSync Video for better performance:

```yaml
# In iac/ansible/inventory/group_vars/frigate/main.yml
frigate_cameras:
  front1:
    ffmpeg:
      inputs:
        - path: "rtsp://127.0.0.1:8554/front1-sub?video=copy"
          input_args: preset-rtsp-restream
          roles:
            - detect
      hwaccel_args: preset-intel-qsv-h264  # Add this line
```

Then apply: `ansible-playbook frigate.yml -l frigate`

### 2. Additional Cameras

Add more cameras by extending the configuration:

```yaml
frigate_go2rtc_streams:
  front1-sub: "rtsp://admin:{PASSWORD}@192.168.6.129/cam/realmonitor?channel=1&subtype=1"

frigate_cameras:
  front1: { ... }
  back1: { ... }
```

### 3. Advanced Features

- **Motion Detection Zones**: Define specific areas for detection
- **Recording Rules**: Configure continuous/event-based recording
- **MQTT Integration**: Connect to Home Assistant or other automation
- **Object Detection**: Configure specific object types (person, car, etc.)
- **Notifications**: Set up alerts for detected events

### 4. Performance Monitoring

- Monitor CPU usage with hardware acceleration disabled
- Test different detection models (CPU vs. hardware accelerated)
- Adjust detection sensitivity and zones as needed

### 5. Backup and Recovery

- Configuration is git-versioned (no manual backup needed)
- Consider backing up detection models and recorded media
- Document custom detection zones and rules

## Troubleshooting

### Common Commands

```bash
# Restart Frigate
ssh root@192.168.6.111 "docker restart frigate"

# View detailed logs with errors
ssh root@192.168.6.111 "docker logs frigate 2>&1 | grep -i error"

# Test camera stream directly
ssh root@192.168.6.111 "docker exec frigate ffmpeg -i 'rtsp://admin:{PASSWORD}@192.168.6.129/cam/realmonitor?channel=1&subtype=1' -t 5 -f null - 2>&1"

# Check GPU acceleration capabilities
ssh root@192.168.6.111 "vainfo"
```

### Quick Debug Bundle

```bash
cd /home/maxo/code/pve/iac/ansible
just frigate-debug-bundle
```

## Notes

- Container runs as privileged to access GPU devices
- Configuration backup is disabled (`FRIGATE_CONFIG_BACKUP=false`)
- All changes should be made through Ansible (avoid manual edits)
- GPU passthrough is configured but hardware acceleration is not yet active
