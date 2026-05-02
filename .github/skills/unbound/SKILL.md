---
name: unbound
description: 'Validate Unbound recursive DNS changes in this Pi-hole suite. Use when: checking Unbound config, port 5335, DNSSEC, root hints refresh, unbound-checkconf, rollback safety, Pi-hole upstream integration, or DNS health.'
argument-hint: 'what changed or host/IP to validate, e.g. root hints, rollback, port 5335, DNSSEC, 10.20.30.3'
---

# Unbound Validation

Use this skill for Unbound-specific review and validation inside the Pi-hole + Unbound suite. It focuses on recursive DNS correctness, DNSSEC, config safety, root hints, rollback behavior, and the Pi-hole upstream contract.

## Inputs

Identify:

- Change scope: installer Unbound setup, root hints refresh, auto-update rollback, rescue restore, DNS health, Pi-hole upstream, API status, or docs/tests.
- Validation target: static repository review, disposable Debian/Raspberry Pi OS host, or existing Pi-hole host/IP.
- Risk level: non-destructive checks only, or destructive config-break/restore tests allowed on a disposable host.

If the user gives a Pi-hole IP, use it for client-side DNS checks. Treat real Raspberry Pi hosts as production DNS by default. Do not assume SSH credentials; ask for host/user before remote commands.

## Decision Flow

1. If working in a non-Linux/VFS workspace, do static validation only and report live checks as pending.
2. If validating a real host, start with read-only DNS, service, config, and API checks.
3. If a command can rewrite `/etc/unbound`, restart services, run restore, upgrade packages, reboot, or affect DNS availability, require explicit user intent and prefer a disposable test host.
4. If root hints or config replacement logic changed, verify that failed validation leaves existing live Unbound config untouched.
5. If Pi-hole upstream behavior changed, confirm Pi-hole still forwards to `127.0.0.1#5335` unless the user deliberately configured another local Unbound port.

## Static Repository Checks

Run the strongest available checks:

```bash
make ci
```

If unavailable, use the relevant subset:

```bash
bash scripts/repo_selftest.sh
bash -n install.sh
find scripts tools -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
shellcheck -x install.sh scripts/*.sh scripts/lib/*.sh tools/*.sh
shfmt -d install.sh scripts tools
python3 -m py_compile start_suite.py
pytest -q
```

For static review, inspect the Unbound-relevant paths:

- `install.sh` for `configure_unbound`, root hints setup, `UNBOUND_PORT`, and Pi-hole upstream configuration.
- `scripts/root_hints_refresh.sh` for download validation, dry-run behavior, `unbound-checkconf`, and reload/restart ordering.
- `scripts/auto_update.sh` for Unbound snapshots and rollback behavior.
- `scripts/rescue_menu.sh` for backup/restore of `/etc/unbound` and Pi-hole upstream repair.
- `scripts/lib/health.sh` and `scripts/boot_health_check.sh` for port 5335 health checks.
- `tests/test_shell_static.py` for regression coverage.

## Host DNS Checks

From a client machine, replace `10.20.30.3` with the Pi-hole IP:

```bash
dig @10.20.30.3 google.com
dig @10.20.30.3 dnssec.works
dig @10.20.30.3 dnssec-failed.org
```

Expected:

- Normal domains resolve through Pi-hole.
- `dnssec.works` resolves.
- `dnssec-failed.org` fails or returns no usable answer when DNSSEC validation is active.

On the Pi-hole host, validate Pi-hole and Unbound separately:

```bash
dig +short @127.0.0.1 google.com
dig +short @127.0.0.1 -p 5335 google.com
dig @127.0.0.1 -p 5335 dnssec.works
dig @127.0.0.1 -p 5335 dnssec-failed.org
```

Expected:

- Port 53 resolves through Pi-hole.
- Port 5335 resolves directly through Unbound.
- DNSSEC failure domains do not validate successfully.

For the user's real Raspberry Pi 4 target, assume Unbound is host-installed and used by Pi-hole on `127.0.0.1#5335`. Do not prioritize container DNS paths unless requested.

## Service And Config Checks

Use read-only checks first:

```bash
systemctl status unbound
sudo unbound-checkconf
sudo grep -R "interface:\|port:\|root-hints:\|auto-trust-anchor-file:" /etc/unbound /etc/unbound/unbound.conf.d 2>/dev/null
sudo grep -A5 '^\[dns\]' /etc/pihole/pihole.toml
```

Expected:

- Unbound listens on the configured local port, normally `5335`.
- Pi-hole upstream includes `127.0.0.1#5335`.
- `unbound-checkconf` succeeds before any reload/restart is treated as safe.
- Root hints point to `/var/lib/unbound/root.hints` or the configured package path used by this suite.

## Root Hints Refresh

Dry-run must be side-effect free:

```bash
sudo env DRY_RUN=1 bash /usr/local/lib/pihole-suite/scripts/root_hints_refresh.sh
```

Live run on a suitable host:

```bash
sudo bash /usr/local/lib/pihole-suite/scripts/root_hints_refresh.sh
sudo grep -q 'A\.ROOT-SERVERS\.NET\.' /var/lib/unbound/root.hints
sudo unbound-checkconf
systemctl status unbound
```

Quality criteria:

- Downloads are staged to a temporary file.
- Content is validated before installation.
- Existing `root.hints` remains untouched after failed download or validation.
- Unbound reload/restart happens only after validation succeeds.
- Cron/systemd paths use `/usr/local/lib/pihole-suite`, not the git checkout.

## Rollback And Restore Safety

For auto-update rollback and rescue restore code, check:

- Live `/etc/unbound` is not deleted before a replacement or rollback is staged.
- `unbound-checkconf` is run before accepting a restored config where practical.
- Failure paths restore the previous live config or leave it untouched.
- Backups under `/var/backups/pihole-suite` reject symlinks and unsafe permissions.
- Snapshot retention prevents unbounded growth on small SD cards.

Do not run destructive break/restore tests on a production DNS host. Use [docs/ACCEPTANCE_TESTS.md](../../../docs/ACCEPTANCE_TESTS.md) on a disposable host.

## Code Review Criteria

Before calling Unbound work complete, verify:

- `UNBOUND_PORT` stays configurable and defaults to `5335`.
- Pi-hole upstream remains aligned with the configured Unbound port.
- Dry-run paths do not edit `/etc/unbound`, `/var/lib/unbound`, Pi-hole config, cron, systemd, state, backups, or services.
- Config writes use staging and validation where practical.
- Root hints refresh uses validation and does not use inline cron download chains.
- DNS health checks include both Pi-hole port 53 and Unbound port 5335.
- Docs/tests are updated when ports, paths, root hints, rollback, or validation behavior changes.

## References

- [docs/CONFIGURATION.md](../../../docs/CONFIGURATION.md) for `UNBOUND_PORT` and runtime paths.
- [docs/SHELL_AND_CONFIG_RULES.md](../../../docs/SHELL_AND_CONFIG_RULES.md) for dry-run and safe config writes.
- [docs/ACCEPTANCE_TESTS.md](../../../docs/ACCEPTANCE_TESTS.md) for live host checks.
- [docs/PLAN_IMPLEMENTATION_AUDIT.md](../../../docs/PLAN_IMPLEMENTATION_AUDIT.md) for current remaining gaps and validation limits.
- [.github/skills/pihole/SKILL.md](../pihole/SKILL.md) for broader suite validation.

## Completion Output

End with:

- What Unbound behavior was reviewed or validated.
- What passed.
- What could not run in the current environment.
- Whether any DNS-impacting live checks remain.
- Any release-blocking Unbound risks.
