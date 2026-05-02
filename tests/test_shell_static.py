from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read_repo_file(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def test_installer_dry_run_guards_state_and_mutating_checks() -> None:
    install = read_repo_file("install.sh")

    assert 'if [[ "$DRY_RUN" == true ]]; then\n    log "DRY RUN: Would update state $1=$2"' in install
    assert 'DRY RUN: Would run health checks for Unbound, Pi-hole, optional NetAlertX, and optional Python Suite' in install
    assert 'DRY RUN: Would ensure Pi-hole v6 upstreams are set to $upstream in $toml_file' in install
    assert 'DRY RUN: Would inspect and adjust systemd-resolved only if it conflicts with Pi-hole port 53' in install


def test_installer_uses_root_owned_runtime_paths_for_unattended_jobs() -> None:
    install = read_repo_file("install.sh")

    assert 'RUNTIME_DIR="/usr/local/lib/pihole-suite"' in install
    assert '$RUNTIME_DIR/scripts/auto_update.sh' in install
    assert '$RUNTIME_DIR/scripts/root_hints_refresh.sh' in install
    assert 'sudo install -m 0755 "$SCRIPT_DIR/scripts/rescue_menu.sh" "$RUNTIME_DIR/scripts/rescue_menu.sh"' in install
    assert 'sudo -- ln -sfn "$RUNTIME_DIR/scripts/rescue_menu.sh" /usr/local/bin/pihole-rescue' in install


def test_installer_has_confirmed_suite_tools_uninstall() -> None:
    install = read_repo_file("install.sh")

    assert '--uninstall-suite-tools) UNINSTALL_SUITE_TOOLS=true ;;' in install
    assert '--yes|-y) ASSUME_YES=true ;;' in install
    assert '--uninstall-suite-tools requires --yes in non-interactive mode' in install
    assert 'sudo rm -f /etc/systemd/system/pihole-boot-check.service /etc/logrotate.d/pihole-auto-update /usr/local/bin/pihole-rescue' in install


def test_rescue_restore_validates_backup_before_copy() -> None:
    rescue = read_repo_file("scripts/rescue_menu.sh")

    assert 'readonly BACKUP_DIR="${PIHOLE_BACKUP_DIR:-${BACKUP_ROOT}/rescue}"' in rescue
    assert 'symlinks=$(find "$bdir" -type l 2>/dev/null)' in rescue
    assert 'unsafe=$(find "$bdir" -type d \\( -perm -002 -o -perm -020 \\) -print -quit 2>/dev/null)' in rescue
    assert 'with_backup_lock "backup restore" _restore_backup_dir "$bdir"' in rescue
    assert 'with_backup_lock "last-known-good restore" _restore_backup_dir "$bdir"' in rescue


def test_auto_update_dry_run_skips_persistent_and_service_actions() -> None:
    auto_update = read_repo_file("scripts/auto_update.sh")

    assert 'DRY_RUN=1 — no snapshots, status files, maintenance, or reboot will be performed' in auto_update
    assert 'DRY_RUN=1 — would acquire lock: $LOCK_FILE' in auto_update
    assert 'DRY_RUN=1 — would compare and validate post-update Unbound config' in auto_update
    assert 'DRY_RUN=1 — would write status to $STATUS_FILE: ${status_parts[*]}' in auto_update
    assert 'DRY_RUN=1 — would send notification if configured' in auto_update
    assert 'readonly SNAPSHOT_RETENTION="${PIHOLE_AUTO_BACKUP_RETENTION:-8}"' in auto_update
    assert 'prune_snapshots "$SNAPSHOT_RETENTION"' in auto_update


def test_root_hints_refresh_is_validated_and_not_inline_cron_chain() -> None:
    root_hints = read_repo_file("scripts/root_hints_refresh.sh")
    install = read_repo_file("install.sh")

    assert 'grep -q \'A\\.ROOT-SERVERS\\.NET\\.\'' in root_hints
    assert 'unbound-checkconf' in root_hints
    assert 'root_hints_entry="0 4 1 * * . $ENV_FILE 2>/dev/null; $RUNTIME_DIR/scripts/root_hints_refresh.sh"' in install
    assert 'root.hints.new https://www.internic.net/domain/named.root &&' not in install


def test_maintenance_backups_use_suite_backup_root() -> None:
    maintenance = read_repo_file("tools/pihole_maintenance_pro.sh")

    assert 'BACKUP_ROOT="${PIHOLE_BACKUP_ROOT:-/var/backups/pihole-suite}"' in maintenance
    assert 'MAINT_BACKUP_ROOT="${PIHOLE_MAINT_BACKUP_DIR:-${BACKUP_ROOT}/maintenance}"' in maintenance
    assert 'install -d -m 0700 -o root -g root "$BACKUP_ROOT" "$MAINT_BACKUP_ROOT" "$backup_dir"' in maintenance
    assert 'prune_maintenance_backups "$MAINT_BACKUP_RETENTION"' in maintenance


def test_repo_selftest_distinguishes_entrypoints_from_libraries() -> None:
    selftest = read_repo_file("scripts/repo_selftest.sh")

    assert "list_executable_shell_scripts()" in selftest
    assert "done < <(list_shell_scripts)" in selftest
    assert "done < <(list_executable_shell_scripts)" in selftest
    assert "Optional localized README missing: README.de.md" in selftest


def test_post_install_check_reports_multiline_upstreams_cleanly() -> None:
    post_install = read_repo_file("scripts/post_install_check.sh")

    assert "in_dns && collecting" in post_install
    assert "upstreams_compact" in post_install
    assert 'pass "Pi-hole v6 upstreams configured correctly: 127.0.0.1#${expected_port}"' in post_install
