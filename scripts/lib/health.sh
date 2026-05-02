#!/usr/bin/env bash
# Shared health-check helpers for Pi-hole + Unbound scripts.

suite_dns_check() {
  local port="$1" domain="${2:-debian.org}"
  local response
  response=$(dig +short +timeout=3 +tries=1 "@127.0.0.1" -p "$port" "$domain" 2>/dev/null)
  [[ -n "$response" && "$response" != "0.0.0.0" ]]
}

suite_dns_health_check() {
  local domain="${1:-debian.org}" max_attempts="${2:-3}" wait_sec="${3:-5}"
  local attempt

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
