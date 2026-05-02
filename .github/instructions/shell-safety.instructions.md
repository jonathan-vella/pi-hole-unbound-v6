---
description: "Use when editing shell scripts in this Pi-hole suite. Enforces dry-run purity, safe config writes, quoting, root-owned runtime paths, and backup/restore safety."
name: "Shell Safety"
applyTo: ["install.sh", "scripts/**/*.sh", "tools/**/*.sh"]
---

# Shell Safety Instructions

Follow [docs/SHELL_AND_CONFIG_RULES.md](../../docs/SHELL_AND_CONFIG_RULES.md) for the full policy. Keep this checklist in mind while editing shell files.

- Keep `--dry-run` and `DRY_RUN=1` side-effect free: no state writes, backups, cron/systemd edits, resolver changes, service restarts, notifications, or reboot.
- Do not make cron, systemd, or global wrappers point at the git checkout. Use root-owned runtime copies under `/usr/local/lib/pihole-suite`.
- Persist unattended config in `/etc/pihole-suite/pihole-suite.env`; do not rely on interactive shell exports.
- Keep mutable state, logs, and backups under `/var/lib/pihole-suite`, `/var/log/pihole-suite`, and `/var/backups/pihole-suite`.
- Stage config writes through temporary files and validate before replacing live files where practical.
- Reject root-restore backups that contain symlinks or unsafe permissions.
- Quote variables, prefer arrays for command construction, and avoid `eval`.
- Do not print secrets such as `SUITE_API_KEY` or webhook URLs.
- After shell edits, run `make shellcheck` and `make format-check` when available; use [docs/ACCEPTANCE_TESTS.md](../../docs/ACCEPTANCE_TESTS.md) for live-host validation.
