#!/bin/bash
# Frigate LXC Installation Script (Debian base, non-Docker)
# Based on provided sample, adapted to repo helpers and idempotent flow.

set -e

# Source helper functions (provided by hook orchestrator)
source /tmp/lxc-helpers.sh 2>/dev/null || true

APP="frigate"
APP_DIR="/opt/frigate"
WHEELS_DIR="/wheels"

# Ensure base directories
ensure_directory "$APP_DIR" "root:root" "755"
ensure_directory "$WHEELS_DIR" "root:root" "755"

# Core OS update is handled by ensure_packages; install deps if missing
# Dependencies from sample script (condensed, non-Docker build)
BASE_DEPS=(
  git ca-certificates automake build-essential xz-utils libtool ccache pkg-config \
  libgtk-3-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev \
  libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff-dev gfortran \
  openexr libatlas-base-dev libssl-dev libtbb-dev libdc1394-dev \
  libopenexr-dev libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev gcc \
  libopenblas-dev liblapack-dev libusb-1.0-0-dev jq moreutils curl wget
)
ensure_packages "${BASE_DEPS[@]}"

# Handle Intel TBB runtime package name differences across Debian versions
if apt-cache show libtbb12 >/dev/null 2>&1; then
  install_if_missing libtbb12 libtbbmalloc2
else
  install_if_missing libtbb2 || true
fi

# Python3 and pip (avoid system pip due to PEP 668; use venv pip instead)
# ensure_packages python3 python3-dev python3-setuptools python3-distutils python3-pip
# python3 -m pip install --upgrade pip || true

# Node.js install not required for Docker deployment
# setup_nodejs 22

# Python venv not used for Docker deployment
# VENV_DIR="/opt/frigate/.venv"; VENV_PY="$VENV_DIR/bin/python"; setup_python_venv "$VENV_DIR" "3.12"; export PATH="$VENV_DIR/bin:$PATH"
# if [ -x "$VENV_PY" ]; then "$VENV_PY" -m ensurepip --upgrade || true; "$VENV_PY" -m pip install --upgrade pip setuptools wheel || true; fi

# go2rtc install (binary download)
if ! command -v go2rtc >/dev/null 2>&1; then
  ensure_directory /usr/local/go2rtc/bin
  (cd /usr/local/go2rtc/bin && \
    curl -fsSL "https://github.com/AlexxIT/go2rtc/releases/latest/download/go2rtc_linux_amd64" -o go2rtc && \
    chmod +x go2rtc && \
    ln -svf /usr/local/go2rtc/bin/go2rtc /usr/local/bin/go2rtc)
fi

# Hardware accel packages (safe for CPU-only; no device config here)
ensure_packages va-driver-all ocl-icd-libopencl1 intel-opencl-icd vainfo intel-gpu-tools || true

# Frigate v0.14.1 source install (disabled; using Docker/Compose per upstream recommendation)
VERSION_TAG="v0.14.1"
if false && version_changed "$APP" "$VERSION_TAG"; then
  echo "Installing Frigate ${VERSION_TAG}..."
  # Fetch source
  rm -rf "$APP_DIR/.tmp" && mkdir -p "$APP_DIR/.tmp"
  curl -fsSL "https://github.com/blakeblackshear/frigate/archive/refs/tags/${VERSION_TAG}.tar.gz" -o "$APP_DIR/.tmp/frigate.tar.gz"
  tar -xzf "$APP_DIR/.tmp/frigate.tar.gz" -C "$APP_DIR" --strip-components 1
  rm -f "$APP_DIR/.tmp/frigate.tar.gz"

  # Patch: disable audio import by default to avoid CPU SIGILL from tflite/tensorflow on older CPUs.
  # We create a stub and swap the import in app.py; this is reversible if you want audio later.
  if [ -f "$APP_DIR/frigate/app.py" ]; then
    ensure_directory "$APP_DIR/frigate/events" "root:root" "755"
    cat >"$APP_DIR/frigate/events/audio_stub.py" <<'PY'
def listen_to_audio(*args, **kwargs):
    # Audio disabled by install script to ensure compatibility on CPUs without AVX/AVX2.
    return
PY
    if grep -q "from frigate.events.audio import listen_to_audio" "$APP_DIR/frigate/app.py"; then
      sed -i 's/from frigate.events.audio import listen_to_audio/from frigate.events.audio_stub import listen_to_audio/' "$APP_DIR/frigate/app.py" || true
    fi
  fi

  # Build wheels (into shared cache dir)
  if [ -f "$APP_DIR/docker/main/requirements-wheels.txt" ]; then
    "$VENV_PY" -m pip wheel --wheel-dir="$WHEELS_DIR" -r "$APP_DIR/docker/main/requirements-wheels.txt"
  fi

  # Install btbn-ffmpeg deps and link ffmpeg
  export TARGETARCH="amd64"
  echo 'libc6 libraries/restart-without-asking boolean true' | debconf-set-selections || true
  # Try upstream deps script (may fail on Debian 12 due to python3.9 assumptions)
  if ! bash "$APP_DIR/docker/main/install_deps.sh"; then
    echo "Upstream install_deps.sh failed; falling back to Debian ffmpeg"
  fi
  apt-get update || true
  if [ -x /usr/lib/btbn-ffmpeg/bin/ffmpeg ]; then
    ln -svf /usr/lib/btbn-ffmpeg/bin/ffmpeg /usr/local/bin/ffmpeg || true
    ln -svf /usr/lib/btbn-ffmpeg/bin/ffprobe /usr/local/bin/ffprobe || true
  else
    # Fallback to Debian ffmpeg
    install_if_missing ffmpeg
    if ! command -v ffmpeg >/dev/null 2>&1; then
      echo "ERROR: ffmpeg not available after fallback install" >&2
    fi
  fi

  # Install Python wheels into venv
  if ls ${WHEELS_DIR}/*.whl >/dev/null 2>&1; then
    "$VENV_PY" -m pip install -U ${WHEELS_DIR}/*.whl || true
  fi

  # Install remaining runtime dependencies directly (avoid building the package)
  if [ -f "$APP_DIR/docker/main/requirements.txt" ]; then
    "$VENV_PY" -m pip install -r "$APP_DIR/docker/main/requirements.txt" || true
  fi

  # Ensure an interpreter for audio events is available to avoid import errors.
  # Prefer lightweight tflite-runtime; if not available for this Python, fall back to TensorFlow.
  if ! "$VENV_PY" -c 'import importlib; importlib.import_module("tflite_runtime.interpreter")' 2>/dev/null; then
    echo "Attempting to install tflite-runtime wheel..."
    if ! "$VENV_PY" -m pip install --only-binary=:all: "tflite-runtime>=2.11,<3"; then
      echo "tflite-runtime wheel unavailable; installing TensorFlow (CPU) as fallback..."
      "$VENV_PY" -m pip install "tensorflow>=2.16,<2.19" || true
    fi
  fi

  # NOTE: We intentionally skip `pip install .` because the repo layout has multiple
  # top-level packages and setuptools aborts automatic discovery. We'll run Frigate
  # from source by setting PYTHONPATH in the systemd unit.

  # Dev requirements for building UI (use venv pip)
  if [ -f "$APP_DIR/docker/main/requirements-dev.txt" ]; then
    "$VENV_PY" -m pip install -r "$APP_DIR/docker/main/requirements-dev.txt" || true
  fi

  # Initialize (from devcontainer init)
  if [ -x "$APP_DIR/.devcontainer/initialize.sh" ]; then
    bash "$APP_DIR/.devcontainer/initialize.sh" || true
  fi

  # Make version (if Makefile supports)
  if command -v make >/dev/null 2>&1; then
    (cd "$APP_DIR" && make version || true)
  fi

  # Web build
  if [ -f "$APP_DIR/web/package.json" ]; then
    (cd "$APP_DIR/web" && npm install)
    # Build UI assets with base '/'
    (cd "$APP_DIR/web" && npm run build -- --base=/) || true
  fi

  track_version "$APP" "$VERSION_TAG"
fi

# RECOMMENDED INSTALL: Docker + Compose

# Install Docker CE and compose plugin on Debian
if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker (Debian)..."
  ensure_packages ca-certificates curl gnupg lsb-release apt-transport-https
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
fi

# Prepare config and media directories
ensure_directory /etc/frigate "root:root" "755"
ensure_directory /opt/frigate "root:root" "755"
ensure_directory /tank/frigate "root:root" "755"

# Minimal default Frigate config (customize later)
if [ ! -f /etc/frigate/config.yml ]; then
  cat >/etc/frigate/config.yml <<'YAML'
mqtt:
  enabled: false
detectors:
  cpu1:
    type: cpu
ui:
  live_provider: go2rtc
go2rtc:
  streams: {}
YAML
fi

# Compose file for Frigate with host networking
TZ_VAL="$(cat /etc/timezone 2>/dev/null || echo UTC)"
cat >/opt/frigate/docker-compose.yml <<YAML
services:
  frigate:
    image: ghcr.io/blakeblackshear/frigate:${VERSION_TAG#v}
    container_name: frigate
    restart: unless-stopped
    network_mode: host
    shm_size: "64mb"
    environment:
      - TZ=${TZ_VAL}
      - FRIGATE_CONFIG_BACKUP=false
    volumes:
      - /etc/frigate:/config:rw
      - /tank/frigate:/media/frigate:rw
      - type: tmpfs
        target: /tmp/cache
        tmpfs:
          size: 100000000
    privileged: false
YAML

# Disable legacy non-Docker services if present
systemctl disable --now frigate 2>/dev/null || true
systemctl disable --now go2rtc 2>/dev/null || true

# Systemd unit to manage the compose stack
create_systemd_service "frigate-compose" '[Unit]
Description=Frigate NVR (Docker Compose)
After=network-online.target docker.service
Wants=network-online.target docker.service

[Service]
Type=oneshot
WorkingDirectory=/opt/frigate
RemainAfterExit=yes
ExecStartPre=-/usr/bin/docker compose pull --quiet
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=300
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target'

ensure_service_running frigate-compose || true

# Final output
LOCAL_IP=$(get_container_ip)
echo "Frigate (Docker) setup complete. Access: http://${LOCAL_IP}:5000"
