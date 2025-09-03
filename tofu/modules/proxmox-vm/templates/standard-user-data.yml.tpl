#cloud-config
hostname: ${hostname}
users:
  - default
  - name: ${admin_user}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    ssh_authorized_keys:
      - ${ssh_public_key}
    password: ${admin_password}
ssh_authorized_keys:
  - ${ssh_public_key}
chpasswd:
  list: |
    ${admin_user}:${admin_password}
    root:${admin_password}
  expire: false
package_update: true
package_upgrade: true
packages:
  - qemu-guest-agent
  - openssh-server
  - curl
  - nano
  - git
${packages}
runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - sleep 5
  - systemctl status qemu-guest-agent --no-pager
  - systemctl enable ssh
  - systemctl start ssh
${scripts}
  - echo "done" > /tmp/cloud-config.done
final_message: "Cloud-init finished. System ready with user ${admin_user}."
