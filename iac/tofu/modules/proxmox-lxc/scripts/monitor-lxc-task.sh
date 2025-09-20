#!/bin/bash
# Monitor PVE task completion for LXC container
set -e

VMID="$1"
NODE="$2"
TIMEOUT="${3:-900}"
PVE_HOST="${4:-pve-01}"

if [[ -z "$VMID" || -z "$NODE" ]]; then
    echo "Usage: $0 <vmid> <node> [timeout] [pve_host]"
    exit 1
fi

echo "Monitoring LXC $VMID startup task on $NODE..."

# Find the most recent vzstart task for this VMID
start_time=$(date +%s)
UPID=""

while [[ -z "$UPID" ]]; do
    current_time=$(date +%s)
    if (( current_time - start_time > 30 )); then
        echo "Could not find vzstart task for VMID $VMID, assuming already completed"
        exit 0
    fi
    
    UPID=$(ssh root@$PVE_HOST "find /var/log/pve/tasks -name '*vzstart:$VMID:*' -newer /tmp/tofu-start-$$-$VMID 2>/dev/null | head -1 | xargs basename 2>/dev/null || grep ':vzstart:$VMID:' /var/log/pve/tasks/active 2>/dev/null | tail -1 | cut -d' ' -f1 || echo ''" | grep -v '^$' | tail -1)
    
    if [[ -z "$UPID" ]]; then
        sleep 2
    fi
done

echo "Found task: $UPID"

# Get log path - find the actual file location
log_path=$(ssh root@$PVE_HOST "find /var/log/pve/tasks -name '$UPID' 2>/dev/null | head -1")

# Tail the log and monitor completion
echo "=== Task Log ==="
ssh root@$PVE_HOST "tail -f '$log_path'" &
tail_pid=$!

# Monitor for completion
while true; do
    current_time=$(date +%s)
    if (( current_time - start_time > TIMEOUT )); then
        kill $tail_pid 2>/dev/null || true
        echo "ERROR: Timeout"
        exit 1
    fi
    
    # Check if task completed
    if ssh root@$PVE_HOST "tail -1 '$log_path' | grep -q '^TASK OK'" 2>/dev/null; then
        kill $tail_pid 2>/dev/null || true
        echo "=== Task completed successfully ==="
        exit 0
    elif ssh root@$PVE_HOST "tail -1 '$log_path' | grep -q '^TASK ERROR'" 2>/dev/null; then
        kill $tail_pid 2>/dev/null || true
        echo "=== Task failed ==="
        exit 1
    fi
    
    sleep 3
done
