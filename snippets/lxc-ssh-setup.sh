#!/bin/bash
if [ "$2" == "post-start" ]; then
  pct exec $1 -- bash -c "
    apt-get update &&
    apt-get install -y openssh-server &&
    systemctl enable ssh &&
    systemctl start ssh &&
    mkdir -p /root/.ssh &&
    chmod 700 /root/.ssh &&
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config &&
    systemctl restart ssh
  "
fi