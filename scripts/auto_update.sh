#!/usr/bin/env bash
# =============================================================================
# auto_update.sh — Hardened weekly auto-update wrapper
# Version: 1.0.0
# Repo:    https://github.com/jonathan-vella/pi-hole-unbound-v6
# =============================================================================
# Runs pihole_maintenance_pro.sh (apt + pihole -up + gravity), validates DNS
# health, and conditionally reboots if a kernel update was applied.
#
# Install:  sudo crontab -e → 0 3 * * 0 /path/to/scripts/auto_update.sh
# Manual:   sudo bash /path/to/scripts/auto_update.sh
# Env vars: NOTIFY_URL  — ntfy.sh / Pushover / webhook URL (optional)
#           DRY_RUN=1   — simulate update flow without snapshots, status writes, maintenance, or reboot
# =============================================================================

# Explicit error handling — do NOT use set -e (we handle failures per-step)
set -uo pipefail
IFS=$'\n\t'
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ---------------------------------------------------------------------------
# CONSTANTS
# ---------------------------------------------------------------------------
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly MAINT_SCRIPT="${REPO_DIR}/tools/pihole_maintenance_pro.sh"
readonly LOCK_FILE="/var/run/pihole-auto-update.lock"
readonly ENV_FILE="/etc/pihole-suite/pihole-suite.env"

if [[ -r "$ENV_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

readonly BACKUP_ROOT="${PIHOLE_BACKUP_ROOT:-/var/backups/pihole-suite}"
readonly SNAPSHOT_DIR="${PIHOLE_AUTO_BACKUP_DIR:-${BACKUP_ROOT}/auto-update}"
readonly SNAPSHOT_RETENTION="${PIHOLE_AUTO_BACKUP_RETENTION:-8}"
readonly LOG_DIR="/var/log/pihole-suite"
readonly LOG_FILE="${LOG_DIR}/auto_update.log"
readonly STATUS_FILE="/var/tmp/pihole_update_status"
readonly PIHOLE_CONF="/etc/pihole/pihole.toml"
readonly UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
readonly REBOOT_REQUIRED_FILE="/var/run/reboot-required"
readonly DNS_TEST_DOMAIN="debian.org"
readonly MAINT_TIMEOUT=2700  # 45 minutes

# ---------------------------------------------------------------------------
# UI SETUP
# ---------------------------------------------------------------------------
_ui_lib="${SCRIPT_DIR}/lib/ui.sh"
if [[ -f "$_ui_lib" ]]; then
  # shellcheck source=/dev/null
  source "$_ui_lib"
  ui_init
else
  # Minimal fallback if ui.sh is missing
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

# ---------------------------------------------------------------------------
# VALIDATE NOTIFY_URL — only allow http(s) schemes
# ---------------------------------------------------------------------------
AUTO_DRY_RUN="${DRY_RUN:-0}"

if [[ -n "${NOTIFY_URL:-}" ]]; then
  if [[ ! "$NOTIFY_URL" =~ ^https?:// ]]; then
    log_warn "NOTIFY_URL must start with http:// or https:// (got: ${NOTIFY_URL%%://*}://…). Disabling notifications."
    unset NOTIFY_URL
  fi
fi

# ---------------------------------------------------------------------------
# STATE VARIABLES
# ---------------------------------------------------------------------------
MAINT_FAILED=false
DNS_BROKEN=false
MAJOR_UPGRADE=false
NEEDS_REBOOT=false
REBOOT_BLOCKED_REASON=""
OLD_PIHOLE_VER=""
OLD_KERNEL=""
UNBOUND_CHECKSUMS_BEFORE=""
SUMMARY=""
SNAPSHOT_RUN_DIR=""

# ---------------------------------------------------------------------------
# ROOT CHECK
# ---------------------------------------------------------------------------
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  printf 'ERROR: Root required. Run with sudo.\n' >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# ENSURE DIRECTORIES EXIST
# ---------------------------------------------------------------------------
if [[ "$AUTO_DRY_RUN" == "1" ]]; then
  log_info "DRY_RUN=1 — no snapshots, status files, maintenance, or reboot will be performed"
else
  install -d -m 0750 -o root -g root "$LOG_DIR"
  install -d -m 0700 -o root -g root "$BACKUP_ROOT" "$SNAPSHOT_DIR"
fi

# ---------------------------------------------------------------------------
# FLOCK — prevent overlapping runs
# ---------------------------------------------------------------------------
if [[ "$AUTO_DRY_RUN" == "1" ]]; then
  log_info "DRY_RUN=1 — would acquire lock: $LOCK_FILE"
else
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    log_err "Another auto_update.sh is already running (lock: $LOCK_FILE). Exiting."
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# LOGGING PREAMBLE
# ---------------------------------------------------------------------------
log_info "========== AUTO-UPDATE START $(date '+%Y-%m-%d %H:%M:%S') =========="

# ========================== PHASE 1: PRE-FLIGHT ============================

preflight_ok=true

# --- Disk space check ---
check_disk_space() {
  local mount="$1" min_mb="$2" label="$3"
  local free_kb
  free_kb=$(df "$mount" 2>/dev/null | awk 'NR==2 {print $4}')
  if [[ -z "$free_kb" ]]; then
    log_warn "Could not check disk space on $mount"
    return 0
  fi
  local free_mb=$((free_kb / 1024))
  if [[ $free_mb -lt $min_mb ]]; then
    log_err "$label: Only ${free_mb} MB free (minimum: ${min_mb} MB). Aborting."
    return 1
  fi
  log_ok "$label: ${free_mb} MB free"
  return 0
}

if ! check_disk_space "/boot" 100 "/boot"; then preflight_ok=false; fi
if ! check_disk_space "/" 500 "/"; then preflight_ok=false; fi

# --- NTP sync check ---
if command -v timedatectl &>/dev/null; then
  ntp_status=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo "unknown")
  if [[ "$ntp_status" != "yes" ]]; then
    log_warn "NTP not synchronized (status: $ntp_status). Continuing anyway."
  else
    log_ok "NTP synchronized"
  fi
fi

# --- apt lock check ---
wait_for_apt_lock() {
  local retries=0 max_retries=12  # 12 × 5s = 60s
  while [[ $retries -lt $max_retries ]]; do
    if ! fuser /var/lib/apt/lists/lock /var/lib/dpkg/lock-frontend &>/dev/null 2>&1; then
      return 0
    fi
    log_info "apt lock held by another process, waiting... (${retries}/${max_retries})"
    sleep 5
    retries=$((retries + 1))
  done
  return 1
}

if ! wait_for_apt_lock; then
  log_err "apt lock still held after 60 seconds. Aborting."
  preflight_ok=false
fi

# --- Stale reboot-required ---
REBOOT_PREEXISTING=false
if [[ -f "$REBOOT_REQUIRED_FILE" ]]; then
  REBOOT_PREEXISTING=true
  log_warn "Reboot was already pending from a previous update. Will continue."
fi

if [[ "$preflight_ok" != true ]]; then
  SUMMARY="[FAIL] Pre-flight checks failed. No updates applied."
  log_err "$SUMMARY"
  [[ "$AUTO_DRY_RUN" == "1" ]] || echo "$(date '+%s') FAIL preflight:FAIL" > "$STATUS_FILE"
  # Send notification if configured
  if [[ "$AUTO_DRY_RUN" != "1" && -n "${NOTIFY_URL:-}" ]]; then
    curl -sf --max-time 10 -d "$SUMMARY" "$NOTIFY_URL" 2>/dev/null || true
  fi
  exit 1
fi

log_ok "Pre-flight checks passed"

# ========================== PHASE 2: SNAPSHOT ==============================

log_info "Creating pre-update snapshot..."

# Snapshot Pi-hole config
if [[ "$AUTO_DRY_RUN" == "1" ]]; then
  log_info "DRY_RUN=1 — would snapshot Pi-hole and Unbound configuration to $SNAPSHOT_DIR"
else
  SNAPSHOT_RUN_DIR="${SNAPSHOT_DIR}/$(date +%Y%m%d_%H%M%S)"
  install -d -m 0700 -o root -g root "$SNAPSHOT_RUN_DIR"
  if [[ -f "$PIHOLE_CONF" ]]; then
    cp -a "$PIHOLE_CONF" "${SNAPSHOT_RUN_DIR}/pihole.toml.pre"
    log_ok "Snapshot: pihole.toml"
  fi
fi

# Snapshot Unbound config
if [[ "$AUTO_DRY_RUN" != "1" && -d "$UNBOUND_CONF_DIR" ]]; then
  cp -a "$UNBOUND_CONF_DIR" "${SNAPSHOT_RUN_DIR}/unbound.conf.d.pre"
  log_ok "Snapshot: unbound.conf.d"
fi

prune_snapshots() {
  local keep="${1:-$SNAPSHOT_RETENTION}"
  local -a old_snapshots=()
  [[ "$keep" =~ ^[0-9]+$ ]] || keep=8
  (( keep > 0 )) || keep=8

  mapfile -t old_snapshots < <(find "$SNAPSHOT_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%T@ %p\n' 2>/dev/null | sort -rn | awk -v keep="$keep" 'NR > keep {print $2}')
  local old_snapshot
  for old_snapshot in "${old_snapshots[@]}"; do
    rm -rf "$old_snapshot" && log_info "Pruned old auto-update snapshot: $old_snapshot"
  done
}

if [[ "$AUTO_DRY_RUN" != "1" ]]; then
  prune_snapshots "$SNAPSHOT_RETENTION"
fi

restore_unbound_snapshot() {
  local snapshot_dir="${SNAPSHOT_RUN_DIR}/unbound.conf.d.pre"
  local restore_dir

  if [[ ! -d "$snapshot_dir" ]]; then
    log_err "No snapshot available for restore"
    return 1
  fi

  restore_dir="$(mktemp -d /tmp/pihole-unbound-restore.XXXXXX)" || return 1
  cp -a "$snapshot_dir/." "$restore_dir/" || {
    rm -rf "$restore_dir"
    log_err "Failed to stage Unbound snapshot restore"
    return 1
  }

  if command -v unbound-checkconf >/dev/null 2>&1; then
    local check_root
    check_root="$(mktemp -d /tmp/pihole-unbound-check.XXXXXX)" || {
      rm -rf "$restore_dir"
      return 1
    }
    mkdir -p "$check_root/etc/unbound"
    cp -a /etc/unbound/. "$check_root/etc/unbound/" 2>/dev/null || true
    rm -rf "$check_root/etc/unbound/unbound.conf.d"
    mkdir -p "$check_root/etc/unbound/unbound.conf.d"
    cp -a "$restore_dir/." "$check_root/etc/unbound/unbound.conf.d/"
    # Best effort: unbound-checkconf does not support an alternate root on all distros.
    rm -rf "$check_root"
  fi

  local previous_dir="${UNBOUND_CONF_DIR}.pre-auto-restore.$(date +%Y%m%d_%H%M%S)"
  if [[ -d "$UNBOUND_CONF_DIR" ]]; then
    mv "$UNBOUND_CONF_DIR" "$previous_dir" || {
      rm -rf "$restore_dir"
      log_err "Failed to preserve current Unbound config before restore"
      return 1
    }
  fi
  mkdir -p "$(dirname "$UNBOUND_CONF_DIR")"
  mv "$restore_dir" "$UNBOUND_CONF_DIR" || {
    [[ -d "$previous_dir" ]] && mv "$previous_dir" "$UNBOUND_CONF_DIR" 2>/dev/null || true
    log_err "Failed to move restored Unbound config into place"
    return 1
  }

  if command -v unbound-checkconf >/dev/null 2>&1 && ! unbound-checkconf >/dev/null 2>&1; then
    rm -rf "$UNBOUND_CONF_DIR"
    [[ -d "$previous_dir" ]] && mv "$previous_dir" "$UNBOUND_CONF_DIR" 2>/dev/null || true
    log_err "Restored Unbound config failed validation; previous config restored"
    return 1
  fi

  rm -rf "$previous_dir" 2>/dev/null || true
  return 0
}

# Record checksums for change detection
if [[ "$AUTO_DRY_RUN" == "1" ]]; then
  log_info "DRY_RUN=1 — would validate changed Unbound config and rollback from snapshot if needed"
elif [[ -d "$UNBOUND_CONF_DIR" ]]; then
  UNBOUND_CHECKSUMS_BEFORE=$(find "$UNBOUND_CONF_DIR" -type f -exec md5sum {} + 2>/dev/null | sort)
fi

# Record current versions
OLD_PIHOLE_VER=$(pihole -v 2>/dev/null | grep -i "core" | grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "unknown")
OLD_KERNEL=$(uname -r)
log_info "Current state: Pi-hole ${OLD_PIHOLE_VER}, kernel ${OLD_KERNEL}"

# ======================== PHASE 3: RUN MAINTENANCE =========================

log_info "Running pihole_maintenance_pro.sh (timeout: ${MAINT_TIMEOUT}s)..."

if [[ "$AUTO_DRY_RUN" == "1" ]]; then
  log_info "DRY_RUN=1 — would run maintenance script: $MAINT_SCRIPT"
elif [[ ! -x "$MAINT_SCRIPT" ]]; then
  log_err "Maintenance script not found or not executable: $MAINT_SCRIPT"
  MAINT_FAILED=true
else
  maint_exit=0
  timeout "$MAINT_TIMEOUT" bash "$MAINT_SCRIPT" 2>&1 || maint_exit=$?

  if [[ $maint_exit -eq 124 ]]; then
    log_err "Maintenance TIMED OUT after ${MAINT_TIMEOUT}s"
    MAINT_FAILED=true
  elif [[ $maint_exit -ne 0 ]]; then
    log_err "Maintenance FAILED (exit code: $maint_exit)"
    MAINT_FAILED=true
  else
    log_ok "Maintenance completed successfully"
  fi
fi

# =================== PHASE 4: POST-UPDATE VALIDATION ======================

# --- Check if Unbound config was modified by apt ---
if [[ "$AUTO_DRY_RUN" == "1" ]]; then
  log_info "DRY_RUN=1 — would compare and validate post-update Unbound config"
elif [[ -d "$UNBOUND_CONF_DIR" ]]; then
  unbound_checksums_after=$(find "$UNBOUND_CONF_DIR" -type f -exec md5sum {} + 2>/dev/null | sort)
  if [[ "$UNBOUND_CHECKSUMS_BEFORE" != "$unbound_checksums_after" ]]; then
    log_info "Unbound config changed during update — validating..."
    if command -v unbound-checkconf &>/dev/null; then
      if ! unbound-checkconf &>/dev/null; then
        log_err "Unbound config BROKEN after update — restoring from snapshot"
        if restore_unbound_snapshot; then
          systemctl restart unbound 2>/dev/null || true
          sleep 3
          if unbound-checkconf &>/dev/null; then
            log_ok "Unbound config restored and validated"
          else
            log_err "Unbound config still broken after restore"
          fi
        else
          log_err "Unbound snapshot restore failed; live config left intact when possible"
        fi
      else
        log_ok "Unbound config changed but passes validation"
        systemctl restart unbound 2>/dev/null || true
        sleep 3
      fi
    else
      log_warn "unbound-checkconf not available — cannot validate config"
    fi
  else
    log_ok "Unbound config unchanged"
  fi
fi

# ==================== PHASE 5: DNS HEALTH CHECK ============================

log_info "Running DNS health check..."
if ! suite_dns_health_check "$DNS_TEST_DOMAIN" 3 5; then
  if [[ "$AUTO_DRY_RUN" == "1" ]]; then
    log_warn "DRY_RUN=1 — DNS health check failed; would attempt service recovery"
    DNS_BROKEN=true
  else
    log_warn "DNS health check failed — attempting service recovery..."
    systemctl restart pihole-FTL unbound 2>/dev/null || true
    sleep 5
    if ! suite_dns_health_check "$DNS_TEST_DOMAIN" 3 5; then
      log_err "DNS BROKEN after recovery attempt"
      DNS_BROKEN=true
    else
      log_ok "DNS recovered after service restart"
    fi
  fi
fi

# ================= PHASE 6: MAJOR VERSION DETECTION ========================

NEW_PIHOLE_VER=$(pihole -v 2>/dev/null | grep -i "core" | grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "unknown")
if [[ "$OLD_PIHOLE_VER" != "unknown" && "$NEW_PIHOLE_VER" != "unknown" ]]; then
  old_major=$(echo "$OLD_PIHOLE_VER" | sed 's/^v//' | cut -d. -f1)
  new_major=$(echo "$NEW_PIHOLE_VER" | sed 's/^v//' | cut -d. -f1)
  if [[ "$old_major" != "$new_major" ]]; then
    log_warn "MAJOR Pi-hole version change: ${OLD_PIHOLE_VER} → ${NEW_PIHOLE_VER}. Manual verification recommended."
    MAJOR_UPGRADE=true
  elif [[ "$OLD_PIHOLE_VER" != "$NEW_PIHOLE_VER" ]]; then
    log_info "Pi-hole updated: ${OLD_PIHOLE_VER} → ${NEW_PIHOLE_VER}"
  fi
fi

# ================== PHASE 7: REBOOT DECISION ===============================

# Signal 1: Debian standard
if [[ -f "$REBOOT_REQUIRED_FILE" ]]; then
  NEEDS_REBOOT=true
  log_info "Reboot signal: $REBOOT_REQUIRED_FILE exists"
fi

# Signal 2: Kernel version mismatch
latest_kernel=$(ls -1v /boot/vmlinuz-* 2>/dev/null | tail -1 | sed 's|.*/vmlinuz-||')
if [[ -n "$latest_kernel" && "$latest_kernel" != "$OLD_KERNEL" ]]; then
  NEEDS_REBOOT=true
  log_info "Reboot signal: kernel mismatch (running: ${OLD_KERNEL}, installed: ${latest_kernel})"
fi

# Determine if reboot should be blocked
if [[ "$DNS_BROKEN" == true ]]; then
  REBOOT_BLOCKED_REASON="DNS is broken"
elif [[ "$MAJOR_UPGRADE" == true ]]; then
  REBOOT_BLOCKED_REASON="Major Pi-hole version change needs manual review"
elif [[ "$MAINT_FAILED" == true && "$REBOOT_PREEXISTING" != true ]]; then
  REBOOT_BLOCKED_REASON="Maintenance failed (reboot was not previously pending)"
fi

# ================== PHASE 8: NOTIFICATION ==================================

# Build summary
status_parts=()
if [[ "$MAINT_FAILED" == true ]]; then
  status_parts+=("maint:FAIL")
else
  status_parts+=("maint:OK")
fi
if [[ "$DNS_BROKEN" == true ]]; then
  status_parts+=("DNS:FAIL")
else
  status_parts+=("DNS:OK")
fi
if [[ "$NEEDS_REBOOT" == true ]]; then
  if [[ -n "$REBOOT_BLOCKED_REASON" ]]; then
    status_parts+=("reboot:BLOCKED")
  else
    status_parts+=("reboot:YES")
  fi
else
  status_parts+=("reboot:no")
fi

if [[ "$MAINT_FAILED" == true || "$DNS_BROKEN" == true ]]; then
  SUMMARY="[FAIL] Auto-update $(date '+%Y-%m-%d'): ${status_parts[*]}"
else
  SUMMARY="[OK] Auto-update $(date '+%Y-%m-%d'): ${status_parts[*]}"
fi

log_info "$SUMMARY"

# Write machine-readable status
if [[ "$AUTO_DRY_RUN" == "1" ]]; then
  log_info "DRY_RUN=1 — would write status to $STATUS_FILE: ${status_parts[*]}"
elif [[ "$MAINT_FAILED" == true || "$DNS_BROKEN" == true ]]; then
  echo "$(date '+%s') FAIL ${status_parts[*]}" > "$STATUS_FILE"
else
  echo "$(date '+%s') OK ${status_parts[*]}" > "$STATUS_FILE"
fi

# Send notification if configured
if [[ "$AUTO_DRY_RUN" == "1" ]]; then
  log_info "DRY_RUN=1 — would send notification if configured"
elif [[ -n "${NOTIFY_URL:-}" ]]; then
  if curl -sf --max-time 10 -d "$SUMMARY" "$NOTIFY_URL" 2>/dev/null; then
    log_ok "Notification sent"
  else
    log_warn "Failed to send notification to $NOTIFY_URL"
  fi
fi

# ================== PHASE 9: REBOOT EXECUTION ==============================

if [[ "$NEEDS_REBOOT" == true ]]; then
  if [[ -n "$REBOOT_BLOCKED_REASON" ]]; then
    log_warn "Reboot BLOCKED: $REBOOT_BLOCKED_REASON"
  elif [[ "$AUTO_DRY_RUN" == "1" ]]; then
    log_info "DRY_RUN=1 — would reboot now, but skipping."
  else
    log_info "Rebooting in 15 seconds (kernel updated)..."
    sync
    sleep 15
    shutdown -r now "Auto-update reboot — $(date '+%Y-%m-%d %H:%M')"
  fi
else
  log_info "No reboot needed"
fi

log_info "========== AUTO-UPDATE END $(date '+%Y-%m-%d %H:%M:%S') =========="