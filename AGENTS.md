# Agent Instructions

Use this file to get productive quickly in this repository. Keep changes small, security-minded, and consistent with the existing Bash-first style.

## Project Shape

- This is a Pi-hole v6 + Unbound installer and management suite for Debian/Raspberry Pi OS.
- Primary real-world target: Raspberry Pi 4 on Debian/Raspberry Pi OS aarch64, Linux `raspi4 6.12.75+rpt-rpi-v8` or similar current Raspberry Pi kernel.
- Core runtime is Bash: `install.sh`, `scripts/*.sh`, `scripts/lib/*.sh`, and `tools/pihole_maintenance_pro.sh`.
- The optional monitoring API is `start_suite.py` using FastAPI, Pydantic, and Python 3.11+.
- The default real setup is host Pi-hole + Unbound with the unattended auto-update/boot-health system and optional Python Suite API. NetAlertX Docker support exists but is not the default priority unless requested.
- DNS chain is: client -> Pi-hole on port 53 -> Unbound on port 5335 -> Internet.

## Live Host Assumptions

- Treat the user's Raspberry Pi as a production DNS host by default.
- Prefer non-destructive validation first: static checks, installer dry-runs, read-only DNS/service checks, and API smoke tests.
- Do not assume SSH credentials or a host/user. Ask before using SSH or any remote command.
- Do not suggest destructive restore, uninstall, resolver rewrites, package upgrades, Docker changes, or reboots on the production host unless the user explicitly asks for that exact live operation.
- If destructive acceptance testing is needed, recommend a disposable Debian/Raspberry Pi OS host or VM.

## Commands To Run

Prefer `make ci` when the needed tools are installed. It matches the repository CI gates.

```bash
make ci
make shellcheck
make format-check
make pycompile
make selftest
make lint
make test
```

Equivalent CI checks are in [.github/workflows/ci.yml](.github/workflows/ci.yml). Manual host validation is documented in [docs/ACCEPTANCE_TESTS.md](docs/ACCEPTANCE_TESTS.md).

## Runtime Boundaries

Do not treat the git checkout as a trusted root runtime location. Cron, systemd, and global wrappers must use root-owned runtime copies.

- Runtime scripts/tools: `/usr/local/lib/pihole-suite`
- Persistent config/secrets: `/etc/pihole-suite/pihole-suite.env`
- Mutable state: `/var/lib/pihole-suite`
- Logs: `/var/log/pihole-suite`
- Protected backups: `/var/backups/pihole-suite`

Configuration variables and defaults are documented in [docs/CONFIGURATION.md](docs/CONFIGURATION.md).

## Safety Rules

Follow [docs/SHELL_AND_CONFIG_RULES.md](docs/SHELL_AND_CONFIG_RULES.md) for installer and maintenance changes. Especially:

- `--dry-run` and `DRY_RUN=1` must be pure simulations: no state writes, backups, cron/systemd edits, resolver changes, service restarts, notifications, or reboot.
- Write config through temporary files and validation where practical; never delete live config before staging a replacement.
- Root restore backups must be root-owned, non-world-writable, and rejected if they contain symlinks.
- Do not print secrets such as `SUITE_API_KEY` or webhook URLs.
- Prefer arrays and quoted variables in shell code. Avoid `eval`.

## Implementation Conventions

- Keep Bash changes POSIX-aware where practical, but existing scripts target Bash and may use arrays, `[[ ]]`, `mapfile`, and `set -euo pipefail` style patterns.
- Use shared helpers when they already exist, especially `scripts/lib/ui.sh` for logging/UI and `scripts/lib/health.sh` for DNS health checks.
- Unattended jobs must explicitly source `/etc/pihole-suite/pihole-suite.env`; do not rely on interactive shell environment.
- Pi-hole v6 config lives in `/etc/pihole/pihole.toml`; keep Pi-hole upstream pointed at `127.0.0.1#5335` unless a user deliberately configures otherwise.
- Runtime copies should be installed with root ownership and conservative permissions.
- Container image defaults may remain configurable, but production docs should recommend pinned tags.

## Testing Expectations

- For shell edits, run at least `make shellcheck` and `make format-check` when available.
- For Python/API edits, run `make pycompile`, `make lint`, and `make test`.
- For installer, backup, auto-update, root-hints, or rescue behavior, also update or consult [docs/ACCEPTANCE_TESTS.md](docs/ACCEPTANCE_TESTS.md).
- Do not run destructive rescue/restore or uninstall tests on a production DNS host first. Use a disposable Debian/Raspberry Pi OS host or VM.

## Documentation Map

Link to these docs rather than duplicating their full content:

- [README.md](README.md): user-facing install and operations overview.
- [docs/CONSOLE_MENU.md](docs/CONSOLE_MENU.md): menu behavior and screenshots.
- [docs/CONFIGURATION.md](docs/CONFIGURATION.md): environment variables and runtime paths.
- [docs/SHELL_AND_CONFIG_RULES.md](docs/SHELL_AND_CONFIG_RULES.md): shell/config write rules.
- [docs/ACCEPTANCE_TESTS.md](docs/ACCEPTANCE_TESTS.md): manual validation checklist.
- [docs/PLAN_IMPLEMENTATION_AUDIT.md](docs/PLAN_IMPLEMENTATION_AUDIT.md): current implementation status and known remaining gaps.
