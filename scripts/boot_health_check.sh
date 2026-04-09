#!/usr/bin/env bash
# =============================================================================
# boot_health_check.sh — Post-reboot DNS validation
# Runs via systemd after boot to verify Pi-hole + Unbound are healthy.
# =============================================================================
set -uo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/pihole-suite/boot_check.log"
readonly DNS_TEST_DOMAIN="${DNS_TEST_DOMAIN:-debian.org}"
readonly STATUS_FILE="/var/tmp/pihole_boot_status"

# Source UI if available
_ui_lib="${SCRIPT_DIR}/lib/ui.sh"
if [[ -f "$_ui_lib" ]]; then
  # shellcheck source=/dev/null
  source "$_ui_lib"
  ui_init
else
  log_info() { printf '[%s] INFO  %s\n' "$(date +%H:%M:%S)" "$*"; }
  log_ok()   { printf '[%s] OK    %s\n' "$(date +%H:%M:%S)" "$*"; }
  log_warn() { printf '[%s] WARN  %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
  log_err()  { printf '[%s] ERR   %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
fi

export UI_LOG_FILE="$LOG_FILE"
mkdir -p "$(dirname "$LOG_FILE")"

log_info "========== BOOT HEALTH CHECK $(date '+%Y-%m-%d %H:%M:%S') =========="

# Wait for services to stabilize after boot
sleep 10

dns_check() {
  local port="$1"
  local response
  response=$(dig +short +timeout=3 +tries=1 "@127.0.0.1" -p "$port" "$DNS_TEST_DOMAIN" 2>/dev/null)
  [[ -n "$response" && "$response" != "0.0.0.0" ]]
}

dns_healthy=false

# First attempt
if dns_check 53 && dns_check 5335; then
  log_ok "DNS healthy on boot (Pi-hole + Unbound)"
  dns_healthy=true
else
  log_warn "DNS check failed after boot — restarting services..."
  systemctl restart pihole-FTL unbound 2>/dev/null || true
  sleep 5

  # Retry
  if dns_check 53 && dns_check 5335; then
    log_ok "DNS recovered after service restart"
    dns_healthy=true
  else
    log_err "DNS BROKEN after boot — manual intervention required"
  fi
fi

# Write status
if [[ "$dns_healthy" == true ]]; then
  echo "$(date '+%s') OK" > "$STATUS_FILE"
else
  echo "$(date '+%s') FAIL" > "$STATUS_FILE"
  # Notification if configured
  if [[ -n "${NOTIFY_URL:-}" ]]; then
    if [[ ! "$NOTIFY_URL" =~ ^https?:// ]]; then
      log_warn "NOTIFY_URL must start with http:// or https://. Skipping notification."
    else
      curl -sf --max-time 10 -d "[FAIL] Pi-hole DNS broken after reboot on $(hostname)" "$NOTIFY_URL" 2>/dev/null || true
    fi
  fi
fi

log_info "========== BOOT HEALTH CHECK END =========="