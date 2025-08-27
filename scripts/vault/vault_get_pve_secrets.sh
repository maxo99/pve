#!/bin/bash
curl -H "X-Vault-Token: ${VAULT_TOKEN}" \
    ${VAULT_ADDR}/v1/ansible/data/proxmox | jq .