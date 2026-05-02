---
description: "Run the Pi-hole suite release readiness checklist and report blockers. Checks CI parity, dry-run safety, runtime paths, backups, auto-update, root hints, docs, and known audit gaps."
name: "Pi-hole Release Check"
argument-hint: "optional focus area, branch/change summary, or Pi-hole host IP"
agent: "agent"
---

Run a release readiness check for this Pi-hole + Unbound suite.

Default deployment context: production Raspberry Pi 4 on Debian/Raspberry Pi OS aarch64, host Pi-hole + Unbound, auto-update/root hints/boot-health enabled, optional Python Suite API. Treat NetAlertX/container paths as secondary unless the change touches them.

Use [AGENTS.md](../../AGENTS.md), [.github/skills/pihole/SKILL.md](../skills/pihole/SKILL.md), [docs/PLAN_IMPLEMENTATION_AUDIT.md](../../docs/PLAN_IMPLEMENTATION_AUDIT.md), [docs/ACCEPTANCE_TESTS.md](../../docs/ACCEPTANCE_TESTS.md), and [docs/SHELL_AND_CONFIG_RULES.md](../../docs/SHELL_AND_CONFIG_RULES.md).

Check and report:

1. CI parity: `make ci`, workflow gates, ShellCheck, shfmt, Python compile, Ruff, pytest, repo self-test.
2. Installer safety: `--dry-run` purity, `--force` state handling, root-owned runtime install, uninstall workflows.
3. Runtime boundaries: `/usr/local/lib/pihole-suite`, `/etc/pihole-suite/pihole-suite.env`, `/var/lib/pihole-suite`, `/var/log/pihole-suite`, `/var/backups/pihole-suite`.
4. DNS correctness: Pi-hole upstream to `127.0.0.1#5335`, Unbound on 5335, DNSSEC sanity checks.
5. Backup/restore safety: protected paths, symlink rejection, permissions, locks, retention.
6. Auto-update/root hints: dry-run behavior, cron/systemd paths, rollback/validation, notifications, retention.
7. API safety: bounded reads, response models, auth, Python 3.11+ dependencies.
8. Documentation drift: README, `.env.example`, config docs, acceptance tests, audit report.
9. Remaining blockers: separate must-fix release blockers from follow-up improvements.
10. Production safety: live-host checks must be non-destructive first and must ask for SSH host/user before remote commands.

Output format:

- **Blockers**: severity-ordered findings with file links.
- **Needs Live Validation**: commands/checks that require a Debian/Raspberry Pi OS host.
- **Passed Static Checks**: what was inspected or run.
- **Recommended Next Steps**: concise release-focused actions.

Do not claim live Pi-hole, Unbound, systemd, cron, Docker, or root behavior was validated unless those commands actually ran successfully in the current environment.
