#!/usr/bin/env bash
# =============================================================================
# boot_health_check.sh — Post-reboot DNS validation
# Runs via systemd after boot to verify Pi-hole + Unbound are healthy.
# =============================================================================
set -uo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ENV_FILE="/etc/pihole-suite/pihole-suite.env"

if [[ -r "$ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

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

_health_lib="${SCRIPT_DIR}/lib/health.sh"
if [[ -f "$_health_lib" ]]; then
  # shellcheck source=/dev/null
  source "$_health_lib"
fi
if ! declare -F suite_dns_health_check >/dev/null 2>&1; then
  suite_dns_check() {
    local port="$1" domain="${2:-debian.org}"
    local response
    response=$(dig +short +timeout=3 +tries=1 "@127.0.0.1" -p "$port" "$domain" 2>/dev/null)
    [[ -n "$response" && "$response" != "0.0.0.0" ]]
  }
  suite_dns_health_check() {
    local domain="${1:-debian.org}" max_attempts="${2:-3}" wait_sec="${3:-5}" attempt
    for attempt in $(seq 1 "$max_attempts"); do
      local pihole_ok=false unbound_ok=false
      if suite_dns_check 53 "$domain"; then pihole_ok=true; fi
      if suite_dns_check 5335 "$domain"; then unbound_ok=true; fi
      if [[ "$pihole_ok" == true && "$unbound_ok" == true ]]; then
        log_ok "DNS health check passed (attempt ${attempt}/${max_attempts})"
        return 0
      fi
      if [[ "$attempt" -lt "$max_attempts" ]]; then
        log_warn "DNS check failed (attempt ${attempt}/${max_attempts}): Pi-hole=$pihole_ok Unbound=$unbound_ok; retrying in ${wait_sec}s"
        sleep "$wait_sec"
      fi
    done
    return 1
  }
fi

export UI_LOG_FILE="$LOG_FILE"
mkdir -p "$(dirname "$LOG_FILE")"

log_info "========== BOOT HEALTH CHECK $(date '+%Y-%m-%d %H:%M:%S') =========="

# Wait for services to stabilize after boot
sleep 10

dns_healthy=false

# First attempt
if suite_dns_health_check "$DNS_TEST_DOMAIN" 1 0; then
  log_ok "DNS healthy on boot (Pi-hole + Unbound)"
  dns_healthy=true
else
  log_warn "DNS check failed after boot — restarting services..."
  systemctl restart pihole-FTL unbound 2>/dev/null || true
  sleep 5

  # Retry
  if suite_dns_health_check "$DNS_TEST_DOMAIN" 1 0; then
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