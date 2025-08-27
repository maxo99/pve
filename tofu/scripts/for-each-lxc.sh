#!/usr/bin/env bash
# Helper: read a command from stdin and execute it for each LXC defined in tofu output.
# Usage: printf '%s\n' "<command using $ID and $NAME>" | ./scripts/for-each-lxc.sh

set -euo pipefail

cmd=$(cat -)
if [ -z "$cmd" ]; then
    echo "Usage: pipe a shell command that uses \$ID and \$NAME into this script"
    exit 1
fi

json=$(tofu output -json lxcs)
for container in $(jq -r 'keys[]' <<< "$json"); do
    id=$(jq -r ".${container}.id" <<< "$json")
    name=$(jq -r ".${container}.name" <<< "$json")
    if [ "$id" != "null" ] && [ -n "$id" ]; then
        ID="$id" NAME="$name" bash -lc "$cmd"
    fi
done
