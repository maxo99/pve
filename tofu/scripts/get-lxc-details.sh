#!/bin/bash
# get-lxc-details.sh - Get LXC container details from Terraform output
# Usage: get-lxc-details.sh <lxc_name> [field]
# Fields: id, name, ip, all

set -e

LXC_NAME="$1"
FIELD="${2:-all}"

if [ -z "$LXC_NAME" ]; then
    echo "Usage: $0 <lxc_name> [field]"
    echo "Fields: id, name, ip, all"
    exit 1
fi

# Get LXC details from Terraform output
LXC_JSON=$(tofu output -json lxcs 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$LXC_JSON" ]; then
    echo "Error: Cannot get Terraform output for LXC containers"
    exit 1
fi

# Extract specific LXC data
LXC_DATA=$(echo "$LXC_JSON" | jq -r ".\"$LXC_NAME\" // empty")
if [ -z "$LXC_DATA" ] || [ "$LXC_DATA" = "null" ]; then
    echo "Error: LXC '$LXC_NAME' not found in Terraform output"
    exit 1
fi

case "$FIELD" in
    "id")
        echo "$LXC_DATA" | jq -r '.id // empty'
        ;;
    "name")
        echo "$LXC_DATA" | jq -r '.name // empty'
        ;;
    "ip")
        LXC_ID=$(echo "$LXC_DATA" | jq -r '.id // empty')
        if [ -n "$LXC_ID" ] && [ "$LXC_ID" != "null" ]; then
            IP=$(ssh pve-01 "pct exec $LXC_ID -- ip addr show eth0 | grep 'inet ' | head -1 | awk '{print \$2}' | cut -d'/' -f1" 2>/dev/null)
            echo "${IP:-Not available}"
        else
            echo "Container not running"
        fi
        ;;
    "all")
        echo "LXC Name: $LXC_NAME"
        echo "ID: $(echo "$LXC_DATA" | jq -r '.id // "N/A"')"
        echo "Name: $(echo "$LXC_DATA" | jq -r '.name // "N/A"')"
        # Try to get IP if container exists
        LXC_ID=$(echo "$LXC_DATA" | jq -r '.id // empty')
        if [ -n "$LXC_ID" ] && [ "$LXC_ID" != "null" ]; then
            IP=$(ssh pve-01 "pct exec $LXC_ID -- ip addr show eth0 | grep 'inet ' | head -1 | awk '{print \$2}' | cut -d'/' -f1" 2>/dev/null)
            echo "IP Address: ${IP:-Not available}"
        else
            echo "IP Address: Container not running"
        fi
        ;;
    *)
        echo "Error: Unknown field '$FIELD'"
        echo "Available fields: id, name, ip, all"
        exit 1
        ;;
esac
