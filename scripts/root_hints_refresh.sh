#!/usr/bin/env bash
set -uo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
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

readonly LOG_FILE="/var/log/pihole-suite/root_hints_refresh.log"
readonly ROOT_HINTS_URL="${ROOT_HINTS_URL:-https://www.internic.net/domain/named.root}"
readonly ROOT_HINTS_FILE="${ROOT_HINTS_FILE:-/var/lib/unbound/root.hints}"
readonly LOCK_FILE="/var/run/pihole-root-hints-refresh.lock"

export UI_LOG_FILE="$LOG_FILE"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  log_err "Root required. Run with sudo."
  exit 1
fi

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  log_info "DRY_RUN=1 — would download, validate, install, and reload root.hints from $ROOT_HINTS_URL"
  exit 0
fi

install -d -m 0750 -o root -g root "$(dirname "$LOG_FILE")"
install -d -m 0755 -o root -g root "$(dirname "$ROOT_HINTS_FILE")"

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  log_err "Another root hints refresh is already running (lock: $LOCK_FILE)."
  exit 1
fi

tmp_file="$(mktemp "${ROOT_HINTS_FILE}.new.XXXXXX")" || exit 1
cleanup() {
  rm -f "$tmp_file" 2>/dev/null || true
}
trap cleanup EXIT

log_info "Downloading root hints from $ROOT_HINTS_URL"
if ! curl -fsSL --max-time 30 -o "$tmp_file" "$ROOT_HINTS_URL"; then
  log_err "Failed to download root hints"
  exit 1
fi

if ! grep -q 'ROOT-SERVERS' "$tmp_file" || ! grep -q 'A\.ROOT-SERVERS\.NET\.' "$tmp_file"; then
  log_err "Downloaded root hints file failed validation"
  exit 1
fi

install -m 0644 -o root -g root "$tmp_file" "$ROOT_HINTS_FILE"
log_ok "Installed validated root hints: $ROOT_HINTS_FILE"

if command -v unbound-checkconf >/dev/null 2>&1; then
  if ! unbound-checkconf >/dev/null 2>&1; then
    log_err "Unbound config failed validation after root hints refresh"
    exit 1
  fi
fi

if command -v systemctl >/dev/null 2>&1; then
  if systemctl is-active --quiet unbound 2>/dev/null; then
    systemctl reload unbound 2>/dev/null || systemctl restart unbound 2>/dev/null || {
      log_err "Failed to reload/restart unbound after root hints refresh"
      exit 1
    }
    log_ok "Unbound reloaded after root hints refresh"
  else
    log_warn "Unbound service is not active; root hints installed but service not reloaded"
  fi
fi
