#!/bin/bash
set -e

# Source helper functions (available via init template)
source /tmp/lxc-helpers.sh 2>/dev/null || true

APP="Pi-hole"

echo "Starting ${APP} configuration (non-interactive)..."

# Skip if already installed (avoid pulling/updating on every startup)
if command -v pihole >/dev/null 2>&1; then
  echo "${APP} already installed; skipping install step."
  exit 0
fi

# Ensure required packages
ensure_packages curl ca-certificates

# Preseed Pi-hole to avoid interactive prompts
mkdir -p /etc/pihole
IPV4_CIDR="$(ip -4 -o addr show dev eth0 | awk '{print $4}' | head -n1 || true)"
printf '%s\n' \
  "PIHOLE_INTERFACE=eth0" \
  "IPV4_ADDRESS=${IPV4_CIDR}" \
  "IPV6_ADDRESS=" \
  "INSTALL_WEB_SERVER=true" \
  "INSTALL_WEB_INTERFACE=true" \
  "DNSMASQ_LISTENING=local" \
  "QUERY_LOGGING=true" \
  > /etc/pihole/setupVars.conf

# Run official installer unattended
curl -fsSL https://install.pi-hole.net | bash /dev/stdin --unattended

# Set admin password from placeholder (replaced by hookscript) and bring DNS up
if command -v pihole >/dev/null 2>&1; then
  pihole -a -p ADMIN_PASSWORD_PLACEHOLDER || true
  pihole -g || true
  pihole restartdns || systemctl restart pihole-FTL.service || true
  pihole status || true
fi

echo "${APP} installation complete. Configuration files are managed externally via confs mapping."
