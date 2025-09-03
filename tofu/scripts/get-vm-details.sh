#!/bin/bash
# get-vm-details.sh - Get VM details from Terraform output
# Usage: get-vm-details.sh <vm_name> [field]
# Fields: id, name, ip_address, all

set -e

VM_NAME="$1"
FIELD="${2:-all}"

if [ -z "$VM_NAME" ]; then
    echo "Usage: $0 <vm_name> [field]"
    echo "Fields: id, name, ip_address, all"
    exit 1
fi

# Get VM details from Terraform output
VM_JSON=$(tofu output -json vms 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$VM_JSON" ]; then
    echo "Error: Cannot get Terraform output for VMs"
    exit 1
fi

# Extract specific VM data
VM_DATA=$(echo "$VM_JSON" | jq -r ".\"$VM_NAME\" // empty")
if [ -z "$VM_DATA" ] || [ "$VM_DATA" = "null" ]; then
    echo "Error: VM '$VM_NAME' not found in Terraform output"
    exit 1
fi

case "$FIELD" in
    "id")
        echo "$VM_DATA" | jq -r '.id // empty'
        ;;
    "name")
        echo "$VM_DATA" | jq -r '.name // empty'
        ;;
    "ip_address")
        echo "$VM_DATA" | jq -r '.ip_address[]? // empty' | head -1
        ;;
    "all")
        echo "VM Name: $VM_NAME"
        echo "ID: $(echo "$VM_DATA" | jq -r '.id // "N/A"')"
        echo "Name: $(echo "$VM_DATA" | jq -r '.name // "N/A"')"
        echo "IP Addresses: $(echo "$VM_DATA" | jq -r '.ip_address[]? // empty' | tr '\n' ' ')"
        ;;
    *)
        echo "Error: Unknown field '$FIELD'"
        echo "Available fields: id, name, ip_address, all"
        exit 1
        ;;
esac
