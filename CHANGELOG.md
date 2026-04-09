# Changelog

All notable changes to this project will be documented in this file.

## [0.3.0] — 2026-04-09

### Added
- **Automated Weekly Update System** (`scripts/auto_update.sh`) — hardened unattended update wrapper with:
  - 45-minute execution timeout
  - Pre-flight checks (disk space, NTP sync, apt lock detection)
  - Pre-update config snapshots to `/var/backups/pihole-auto`
  - Unbound config validation with automatic rollback on failure
  - DNS health checks with 3 retries on port 53 and 5335
  - Major Pi-hole version detection
  - Dual reboot signals (`reboot-required` file + kernel mismatch)
  - Reboot blocking when DNS is broken (safety guard)
  - Optional webhook notifications via `NOTIFY_URL` env var
  - Dry-run mode (`DRY_RUN=1`)
- **Boot Health Check** (`scripts/boot_health_check.sh`) — post-reboot DNS validation via systemd oneshot, auto-restarts services if DNS is down, writes status to `/var/tmp/pihole_boot_status`
- **Systemd unit** (`config/pihole-boot-check.service`) — oneshot service running boot health check after `network-online.target`
- **Logrotate config** (`config/logrotate-pihole-auto-update`) — weekly rotation for `/var/log/pihole-suite/auto_update.log` (8 rotations, compressed)
- **Installer flag** `--with-auto-update` — opt-in installation of cron jobs, logrotate config, systemd boot check service, and required directories
- **Rescue & Backup Menu** (`scripts/rescue_menu.sh` v1.0.0) — standalone interactive recovery tool with:
  - System status check (services, DNS, ports, temperature)
  - DNS loop / upstream check with blocking test
  - Nightly diagnostic integration
  - Backup & restore (pihole.toml, Unbound config, systemd drop-ins)
  - Last-Known-Good restore
  - Emergency DNS bypass (sets Pi directly to 8.8.8.8/1.1.1.1, fully reversible)
  - Pi-hole → Unbound standard fix
  - Router / client DNS hint (FritzBox guide)
  - Session log at `/var/log/pihole-rescue-menu.log`
- **Global rescue command**: `/usr/local/bin/pihole-rescue` (symlink installed by rescue setup)
- **Console menu** (`scripts/console_menu.sh`): new option [7] Rescue & Backup Menu links to `pihole-rescue`
- **Unified output format**: `tools/pihole_maintenance_pro.sh` `run_step()` now uses `log_ok`/`log_warn`/`log_err` from `scripts/lib/ui.sh`

### Changed
- Console menu Exit moved from [7] to [8] to accommodate new Rescue entry
- `action_check_mode()` in console menu now also validates rescue_menu availability

### Security
- **NOTIFY_URL validation**: `auto_update.sh` and `boot_health_check.sh` now reject non-HTTP(S) URL schemes (prevents SSRF via `file://`, `ftp://`, etc.)
- **Upstream input sanitization**: `rescue_menu.sh` `_set_pihole_upstream()` validates IP#port format (IPv4 + IPv6) before passing to `pihole --config`
- **Backup restore symlink check**: `rescue_menu.sh` scans backup directories for symlinks before restoring (prevents symlink-based overwrites)
- **Constant-time API key comparison**: `start_suite.py` uses `hmac.compare_digest()` instead of `!=` for API key validation
- **Root hints integrity check**: Monthly cron validates downloaded `named.root` contains expected `ROOT-SERVERS` pattern before replacing
- **Separated dev/prod dependencies**: `ruff` and `pytest` moved from `requirements.txt` to `requirements-dev.txt`
- Expanded `SECURITY.md` with disclosure timeline, CVSS guidance, API key rotation, and security best practices

### Fixed
- **Stale directory name**: All documentation references updated from `Pi-hole-Unbound-PiAlert-Setup` to `pi-hole-unbound-v6`
- **Hardcoded systemd path**: `pihole-boot-check.service` no longer hardcodes `/home/jonathan/...`; `install.sh --with-auto-update` dynamically sets `ExecStart` to actual repo location
- **Broken rescue menu option 3**: `rescue_menu.sh` nightly test path changed from hardcoded `/home/pi/Pi-hole-Unbound-PiAlert-Setup/...` to dynamic `$SCRIPT_DIR`-relative path
- `BACKUP_DIR` in `rescue_menu.sh` now configurable via `PIHOLE_BACKUP_DIR` environment variable
- `DNS_TEST_DOMAIN` in `boot_health_check.sh` now configurable via environment variable
- `repo_selftest.sh` updated to check for new files (`auto_update.sh`, `boot_health_check.sh`, config files)
- Documented all `install.sh` flags in both READMEs (--with-auto-update, --minimal, --force, --dry-run, etc.)
- Added error recovery section in both READMEs
- **Dependabot** (`.github/dependabot.yml`) — automated weekly dependency scanning for pip and GitHub Actions
- **ShellCheck config** (`.shellcheckrc`) — standardized linting rules across all shell scripts

## [0.2.0] — 2026-01-02

### Added
- Post-install verification tool: `scripts/post_install_check.sh`
  (`--quick`, `--full`, `--urls`, `--steps` modes)
- Interactive console menu: `scripts/console_menu.sh`
  (dialog UI if available, text fallback; `--check` mode)
- Repository self-test: `scripts/repo_selftest.sh`
  (syntax checks, permissions, basic sanity)
- Maintenance tool: `tools/pihole_maintenance_pro.sh`
  (optional, invoked via console menu with confirmation)
- Shared UI library: `scripts/lib/ui.sh`
  (colors, log helpers, confirm/pause — used by all scripts)
- Nightly test runner: `scripts/nightly_test.sh`

### Changed
- Installer persists Pi-hole v6 DNS upstream via `/etc/pihole/pihole.toml`
- Documentation expanded with manual verification steps and console menu usage

### Fixed
- Removed non-portable whitespace regex usage in sed (use POSIX `[[:space:]]`)

## [0.1.0] — 2025-01-01

- Initial repository: installer, basic docs, setup flow for Pi-hole + Unbound
