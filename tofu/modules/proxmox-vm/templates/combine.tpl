${base_config}

# Configurazioni personalizzate per questa VM
# Hostname specifico
hostname: ${hostname}

# Chiave SSH aggiuntiva
users:
  - name: root
    ssh_authorized_keys:
      - ${ssh_pub_key}
  - name: ${default_user}
    ssh_authorized_keys:
      - ${ssh_pub_key}

# Configurazioni custom
${custom_config}
