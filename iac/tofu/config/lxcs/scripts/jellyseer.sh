#!/usr/bin/env bash
set -euo pipefail

# Minimal, idempotent installer/updater for Jellyseerr
APP="Jellyseerr"
APP_DIR=/opt/jellyseerr
REPO=https://github.com/Fallenbagel/jellyseerr.git
SYSTEMD_SERVICE=/etc/systemd/system/jellyseerr.service
NODE_MAJOR_REQUIRED=22

header_info() { echo "==> $APP"; }

ensure_packages() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  DEPS=(curl git gnupg ca-certificates jq lsb-release)
  for p in "${DEPS[@]}"; do
    if ! dpkg -s "$p" >/dev/null 2>&1; then
      apt-get install -y --no-install-recommends "$p"
    fi
  done
}

setup_node_repo_if_needed() {
  if command -v node >/dev/null 2>&1; then
    cur_major=$(node -v | cut -d. -f1 | tr -d 'v' | cut -c1-2 || echo 0)
  else
    cur_major=0
  fi
  if [ "$cur_major" -ne "$NODE_MAJOR_REQUIRED" ]; then
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR_REQUIRED}.x | bash -
    apt-get update
    apt-get install -y nodejs
  fi
}

install_or_update_pnpm() {
  # Determine desired pnpm version from package.json if present, else default to ^9.0.0
  desired_pnpm="^9.0.0"
  if [ -f "$APP_DIR/package.json" ]; then
    eng=$(jq -r '.engines.pnpm // empty' "$APP_DIR/package.json" 2>/dev/null || true)
    if [ -n "$eng" ]; then
      desired_pnpm="$eng"
    fi
  fi
  # Extract major version number (fallback to 9)
  case "$desired_pnpm" in
    ^[0-9]*) major=$(echo "$desired_pnpm" | sed -E 's/\^?([0-9]+).*/\1/') || major="9" ;;
    *) major=$(echo "$desired_pnpm" | sed -E 's/\^?([0-9]+).*/\1/' 2>/dev/null || echo "9") ;;
  esac
  # Force-install pnpm at the desired major (install latest 9.x via 'pnpm@9')
  npm install -g "pnpm@${major}"
  pnpm_current=$(pnpm --version 2>/dev/null || true)
  cur_major=$(echo "$pnpm_current" | cut -d. -f1 || echo "")
  if [ -z "$pnpm_current" ] || [ "$cur_major" != "$major" ]; then
    echo "ERROR: failed to install pnpm major ${major} (found ${pnpm_current})" >&2
    exit 1
  fi
}

create_systemd_service() {
  cat <<EOF >"$SYSTEMD_SERVICE"
[Unit]
Description=$APP Service
After=network.target

[Service]
Environment=NODE_ENV=production
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node dist/index.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload || true
  systemctl enable --now jellyseerr || true
}

update_repo_and_build() {
  if [ ! -d "$APP_DIR" ]; then
    git clone "$REPO" "$APP_DIR"
  fi
  cd "$APP_DIR"
  git pull --no-rebase || true
  install_or_update_pnpm
  if command -v pnpm >/dev/null 2>&1; then
  pnpm install --frozen-lockfile || pnpm install
  # Update caniuse-lite to avoid browserslist prompts
  pnpm update --no-save caniuse-lite || true
  export NODE_OPTIONS="--max-old-space-size=3072"
  pnpm build || true
  else
  npm ci || npm install || true
  # Update caniuse-lite via npx to avoid browserslist prompts
  npx update-browserslist-db@latest --update-db || true
  export NODE_OPTIONS="--max-old-space-size=3072"
  npm run build || true
  fi
}

start_or_update() {
  header_info
  ensure_packages
  setup_node_repo_if_needed
  update_repo_and_build
  create_systemd_service
  systemctl restart jellyseerr || true
}

start_or_update
