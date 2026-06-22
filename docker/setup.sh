#!/bin/bash
# setup.sh — One-shot provisioning script for a fresh VM.
# Run once: sudo bash setup.sh
# After that, just use: docker compose up -d

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERTS_DIR="$SCRIPT_DIR/certs"

log() { echo "[setup $(date '+%H:%M:%S')] $*"; }

# ── Root check ───────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo bash setup.sh"
  exit 1
fi

# ── 1. System packages ──────────────────────────────────────────
log "Waiting for apt lock to clear..."
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  log "dpkg locked — waiting..."
  sleep 5
done

apt-get update -y
#apt-get install -y git docker.io docker-compose-plugin ufw openssl curl

# ── 2. Firewall ─────────────────────────────────────────────────
log "Configuring firewall..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# ── 3. Docker ────────────────────────────────────────────────────
log "Enabling Docker..."
systemctl enable docker
systemctl start docker

# ── 4. Self-signed TLS certificate ──────────────────────────────
if [ ! -f "$CERTS_DIR/cert.pem" ] || [ ! -f "$CERTS_DIR/key.pem" ]; then
  log "Generating self-signed TLS certificate..."
  mkdir -p "$CERTS_DIR"
  openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout "$CERTS_DIR/key.pem" \
    -out    "$CERTS_DIR/cert.pem" \
    -subj   "/CN=localhost"
  log "Certificate created."
else
  log "Certificates already exist — skipping."
fi

# ── 5. Fix wp-content permissions ────────────────────────────────
log "Fixing wp-content ownership..."
mkdir -p "$SCRIPT_DIR/wp/wp-content"
chown -R 33:33 "$SCRIPT_DIR/wp/wp-content"

# ── 6. Launch ────────────────────────────────────────────────────
# Use whichever Compose is present: v2 plugin ("docker compose") or
# the v1 standalone ("docker-compose", which cloud-init installs via packages).
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"
else
  echo "Error: neither 'docker compose' nor 'docker-compose' is available" >&2
  exit 1
fi
log "Using Compose command: $DC"

log "Starting Docker Compose stack..."
cd "$SCRIPT_DIR"
$DC down --remove-orphans 2>/dev/null || true
$DC up -d

log ""
log "  Stack is starting up. Check logs with:"
log "    $DC logs -f"
log ""
log "  Endpoints (after ~30s for MySQL init):"
log "    HTTP  : http://localhost"
log "    HTTPS : https://localhost"
log ""
