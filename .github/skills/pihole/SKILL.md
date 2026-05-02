---
name: pihole
description: 'Validate Pi-hole + Unbound suite changes. Use when: checking installer dry-run safety, DNS health, root-owned runtime paths, backups, auto-update, root hints, rescue workflows, or release readiness for this repository.'
argument-hint: 'what changed or what host/IP to validate, e.g. installer dry-run, auto-update, 10.20.30.3, release check'
---

# Pi-hole Suite Validation

Use this skill to review or validate changes to the Pi-hole + Unbound installer and management suite. It turns the project review workflow into a repeatable checklist for code changes, release checks, or host validation.

## Inputs

Identify what the user wants validated:

- Change scope: installer, auto-update, rescue/backup, root hints, maintenance, API, docs, or release readiness.
- Validation target: static repo-only review, disposable Linux host, or existing Pi-hole host/IP.
- Risk level: non-destructive checks only, or destructive restore/uninstall tests allowed on a disposable host.

If the user gives a Pi-hole IP, use it for client-side DNS checks. Treat real Raspberry Pi hosts as production DNS by default. Do not assume SSH credentials; ask for host/user before remote commands.

## Decision Flow

1. If the request is repo-only or the workspace is non-Linux/VFS, do static validation and point live checks to [docs/ACCEPTANCE_TESTS.md](../../../docs/ACCEPTANCE_TESTS.md).
2. If the request involves a real Pi-hole host, start with non-destructive DNS checks, read-only service checks, API smoke tests, and dry-run commands.
3. If testing backup restore, uninstall, resolver rewrites, package upgrades, Docker changes, reboot, or service mutation, warn that those belong on a disposable Debian/Raspberry Pi OS host first unless the user explicitly confirms the live operation.
4. If implementation work changed safety-sensitive behavior, update or consult [docs/PLAN_IMPLEMENTATION_AUDIT.md](../../../docs/PLAN_IMPLEMENTATION_AUDIT.md) and [docs/SHELL_AND_CONFIG_RULES.md](../../../docs/SHELL_AND_CONFIG_RULES.md).

## Static Repository Checks

Run the closest available checks for the environment:

```bash
make ci
```

If `make ci` cannot run, use individual checks:

```bash
bash scripts/repo_selftest.sh
bash -n install.sh
find scripts tools -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
shellcheck -x install.sh scripts/*.sh scripts/lib/*.sh tools/*.sh
shfmt -d install.sh scripts tools
python3 -m py_compile start_suite.py
ruff check .
pytest -q
```

In restricted workspaces, use file inspection and diagnostics instead of pretending live commands ran.

## Client-Side DNS Checks

When given a Pi-hole IP such as `10.20.30.3`, validate from a client machine:

```bash
dig @10.20.30.3 google.com
dig @10.20.30.3 pi-hole.net
dig @10.20.30.3 dnssec.works
dig @10.20.30.3 dnssec-failed.org
```

Expected behavior:

- Normal domains resolve.
- `dnssec.works` resolves.
- `dnssec-failed.org` fails or returns no usable answer when DNSSEC validation is working.
- Pi-hole admin UI is reachable at `http://<pihole-ip>/admin`.
- Pi-hole upstream is `127.0.0.1#5335` unless deliberately configured otherwise.

## Production Raspberry Pi Defaults

For this project, assume the main real host is a Raspberry Pi 4 on Debian/Raspberry Pi OS aarch64. Default validation should focus on host Pi-hole + Unbound, auto-update/root hints/boot-health, and the optional Python Suite API. Do not prioritize NetAlertX or container Pi-hole checks unless requested.

## Installer And Runtime Validation

For installer changes, verify dry-run purity before live runs:

```bash
sudo ./install.sh --dry-run
sudo ./install.sh --dry-run --with-auto-update
sudo ./install.sh --dry-run --force
```

Dry-run must not create state, backups, cron entries, systemd units, resolver edits, package/container changes, service restarts, notifications, or reboots.

For live install validation on a suitable host:

```bash
sudo ./install.sh --with-auto-update
bash scripts/post_install_check.sh --quick
sudo bash scripts/post_install_check.sh --full
```

Confirm root-owned runtime copies, not checkout paths:

```bash
ls -la /usr/local/lib/pihole-suite
ls -la /usr/local/lib/pihole-suite/scripts/lib
ls -la /usr/local/bin/pihole-rescue
sudo crontab -l
systemctl cat pihole-boot-check.service
```

Expected runtime paths are documented in [docs/CONFIGURATION.md](../../../docs/CONFIGURATION.md).

## Backup, Auto-Update, And Root Hints Checks

Validate auto-update safely first:

```bash
sudo DRY_RUN=1 /usr/local/lib/pihole-suite/scripts/auto_update.sh
```

Validate root hints safely first:

```bash
sudo DRY_RUN=1 /usr/local/lib/pihole-suite/scripts/root_hints_refresh.sh
```

Validate maintenance backups without running apt/Pi-hole upgrades:

```bash
sudo bash tools/pihole_maintenance_pro.sh --backup --no-apt --no-upgrade --no-gravity
sudo ls -la /var/backups/pihole-suite/maintenance
```

Rescue backup and restore tests must follow [docs/ACCEPTANCE_TESTS.md](../../../docs/ACCEPTANCE_TESTS.md), especially tampered-backup rejection and symlink safety.

## Code Review Criteria

For any Pi-hole suite change, check these before calling it done:

- Dry-run paths are side-effect free.
- Cron/systemd/global wrappers use `/usr/local/lib/pihole-suite`, not the git checkout.
- Persistent config is read from `/etc/pihole-suite/pihole-suite.env` for unattended jobs.
- State, logs, and backups stay under `/var/lib/pihole-suite`, `/var/log/pihole-suite`, and `/var/backups/pihole-suite`.
- Backup restore rejects symlinks and unsafe permissions.
- Config writes stage temporary files and validate before replacing live files where practical.
- Secrets such as `SUITE_API_KEY` and webhook URLs are not printed.
- Shell changes keep variables quoted and avoid `eval`.
- Python API changes keep bounded file reads and Pydantic response models.
- Docs and tests are updated when flags, paths, backup behavior, or validation workflows change.

## Completion Output

End with:

- What was validated.
- What passed.
- What could not be run in the current environment.
- Any remaining risk or live-host checks still required.
- File links for changed or relevant docs.
