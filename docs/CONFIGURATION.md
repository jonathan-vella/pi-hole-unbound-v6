# Configuration

Persistent runtime configuration lives in `/etc/pihole-suite/pihole-suite.env`. The installer creates this file when needed and unattended cron/systemd jobs source it explicitly.

| Variable | Default | Purpose |
|---|---|---|
| `SUITE_API_KEY` | generated | Required API key for `start_suite.py`. Never print this in logs. |
| `SUITE_PORT` | `8090` | Port for the optional FastAPI suite. |
| `SUITE_HOST` | `127.0.0.1` | Bind address for the optional FastAPI suite. |
| `SUITE_DATA_DIR` | `/var/lib/pihole-suite/data` | Data/cache directory for the optional FastAPI suite. |
| `SUITE_LOG_LEVEL` | `INFO` | API log level. |
| `UNBOUND_PORT` | `5335` | Local Unbound listener used by Pi-hole. |
| `NETALERTX_PORT` | `20211` | NetAlertX web port. |
| `NOTIFY_URL` | empty | Optional HTTP(S) webhook used by auto-update and boot health checks. |
| `DNS_TEST_DOMAIN` | `debian.org` | Domain used by unattended DNS health checks. |
| `PIHOLE_BACKUP_ROOT` | `/var/backups/pihole-suite` | Root for protected backups. Must remain root-owned and non-world-writable. |
| `PIHOLE_AUTO_BACKUP_DIR` | `/var/backups/pihole-suite/auto-update` | Auto-update snapshot directory. |
| `PIHOLE_AUTO_BACKUP_RETENTION` | `8` | Number of timestamped auto-update snapshots to keep. |
| `PIHOLE_BACKUP_DIR` | `/var/backups/pihole-suite/rescue` | Rescue backup directory. |
| `PIHOLE_MAINT_BACKUP_DIR` | `/var/backups/pihole-suite/maintenance` | Maintenance backup directory. |
| `PIHOLE_MAINT_BACKUP_RETENTION` | `5` | Number of maintenance backups to keep. |
| `PIHOLE_IMAGE` | `pihole/pihole:2026.04.1` | Optional Pi-hole container image override. Defaults to a pinned stable tag. |
| `NETALERTX_IMAGE` | `jokobsk/netalertx:26.4.6` | Optional NetAlertX container image override. Defaults to a pinned stable tag. |
| `DRY_RUN` | unset | For `scripts/auto_update.sh`, `DRY_RUN=1` simulates without snapshots, status writes, maintenance, service restarts, notifications, or reboot. |

Installer `--dry-run` is a pure simulation: it must not create persistent files, modify installer state, alter cron/systemd, edit resolver files, install packages, or rewrite Pi-hole/Unbound configuration.
