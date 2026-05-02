# Plan Implementation Audit

Audit date: 2026-05-02

Scope: checked current repository changes against `docs/OPTIMIZATION_PLAN.md` items 1-27. This audit uses static inspection and VS Code diagnostics in the GitHub VFS workspace. Live installer, systemd, cron, Docker, Pi-hole, Unbound, and restore workflows still require disposable-host validation.

## Summary

| Item | Status | Evidence / Notes |
|---|---|---|
| 1. Add GitHub Actions CI | Complete | `.github/workflows/ci.yml` runs shell syntax, repo self-test, ShellCheck, shfmt, Python compile, Ruff, and pytest. |
| 2. Add Python Tool Configuration | Complete | `pyproject.toml` configures Ruff/pytest, Python 3.11 target, and generated/runtime excludes. |
| 3. Add Dry-Run Regression Tests | Partial | Static regression tests cover key dry-run guardrails in `tests/test_shell_static.py`; real mocked root-command execution is not implemented. Manual checks are in `docs/ACCEPTANCE_TESTS.md`. |
| 4. Make `--dry-run` Pure Simulation | Complete by static review | Installer dry-run no-ops state writes, skips health checks, avoids resolver/systemd/cron/runtime writes, and does not mark state OK. Live-host verification pending. |
| 5. Harden Installer State Handling | Complete by static review | State is advisory; `--force` resets flags before validation. Live repair behavior still needs disposable-host validation. |
| 6. Escape Or Regenerate Systemd Unit Writes | Complete | Installer generates `pihole-boot-check.service` from a heredoc and verifies with `systemd-analyze` when available. |
| 7. Install Root-Owned Runtime Copies | Mostly complete | Runtime files install under `/usr/local/lib/pihole-suite`; cron/systemd/global rescue use runtime copies. Existing arbitrary stale systemd/cron entries outside suite-managed patterns are not exhaustively detected. |
| 8. Add Disable And Uninstall Workflows | Complete | `--disable-auto-update`, `--uninstall-auto-update`, and confirmed `--uninstall-suite-tools` are implemented and documented. |
| 9. Move Backups To `/var/backups/pihole-suite` | Complete | Rescue, auto-update, and maintenance backups now default under `/var/backups/pihole-suite`; legacy rescue path is documented as migration-only. |
| 10. Harden Restore And Delete Operations | Mostly complete | Rescue restore paths share symlink/permission validation and `flock`. Restore still copies into live paths directly after validation rather than staging every file type. |
| 11. Make Auto-Update Rollback Atomic | Mostly complete | Auto-update stages snapshot restore, preserves previous live config, validates after move, and restores previous on validation failure. Validation before replacement is limited by `unbound-checkconf` lacking alternate-root support. Snapshot retention implemented. |
| 12. Add Tests For `start_suite.py` | Partial | Tests cover auth, health, tail reads, log parsing, and upstream parsing. Endpoint coverage for `/version`, `/urls`, `/pihole`, `/unbound`, `/leases`, `/stats`, timeout/missing-command paths remains incomplete. |
| 13. Add Typed API Response Models | Complete | Pydantic models and `response_model` are added for API routes. |
| 14. Bound API File Reads And Expensive Checks | Partial | Bounded tail reads and limit clamps exist. TTL caching for expensive derived stats was not added. |
| 15. Centralize Pi-hole Upstream Handling | Partial | Python uses `tomllib`; installer dry-run/backup churn improved. Shell-side upstream parsing/writing is still duplicated in installer, rescue, and post-install check. |
| 16. Centralize DNS And Service Health Checks | Partial | `scripts/lib/health.sh` is added and used by auto-update and boot health. Installer, post-install check, rescue menu, and maintenance still have duplicate health/service checks. |
| 17. Make Container Images Configurable And Pinned | Mostly complete | `PIHOLE_IMAGE` and `NETALERTX_IMAGE` are configurable and documented with production pinning guidance. Defaults remain `latest`, which the plan allowed only if documented. |
| 18. Harden Root Hints Refresh | Complete | `scripts/root_hints_refresh.sh` validates downloads and is used by cron and installer Unbound configuration. |
| 19. Avoid Unnecessary Installer Backup Churn | Complete | Pi-hole TOML fast-path now runs before backup creation. |
| 20. Persist Unattended Notification Configuration | Complete | Auto-update sources `/etc/pihole-suite/pihole-suite.env`; systemd unit uses `EnvironmentFile`; docs updated. |
| 21. Standardize Logs And Status Files | Mostly complete | Log/status paths documented; auto-update and boot status use machine-readable epoch-prefixed values. Some older maintenance logs remain outside `/var/log/pihole-suite`. |
| 22. Add Manual Disaster-Recovery Acceptance Tests | Complete | `docs/ACCEPTANCE_TESTS.md` documents dry-run, runtime, backup tamper, auto-update, root hints, retention, and API smoke checks. |
| 23. Fix Stale Commands And Paths | Complete | README, German README, console docs, and final installer hint were updated. |
| 24. Document Configuration Variables | Complete | `.env.example` and `docs/CONFIGURATION.md` document runtime, backup, image, and dry-run variables. |
| 25. Document Shell And Config-Write Rules | Complete | `docs/SHELL_AND_CONFIG_RULES.md` added. |
| 26. Trim Or Use Unused Python Dependencies | Complete | Runtime deps trimmed to FastAPI/Uvicorn/Pydantic; `httpx` moved to dev requirements for tests. |
| 27. Add Developer Convenience Commands | Complete | `Makefile` includes `lint`, `test`, `selftest`, `format-check`, `pycompile`, `shellcheck`, and `ci`. |

## Remaining Gaps To Consider Before Release

1. Add deeper executable dry-run tests with stubs/mocks for privileged commands, not only static assertions.
2. Expand `start_suite.py` tests to all documented endpoints and subprocess failure paths.
3. Finish shared Pi-hole upstream helpers across installer, rescue, post-install check, and API.
4. Extend `scripts/lib/health.sh` adoption to installer, post-install check, rescue menu, and maintenance scripts.
5. Decide whether to pin non-`latest` default container image tags, or keep current defaults with documented production override guidance.
6. Run CI and the manual acceptance checklist on a disposable Debian/Raspberry Pi OS host.

## Validation Performed In Workspace

- VS Code diagnostics: no errors reported.
- Static grep checks for stale paths and commands: remaining hits are plan text, explicit compatibility notes, or regression-test negative assertions.
- Tooling/files reviewed: CI workflow, Makefile, installer, rescue menu, auto-update, boot health, root hints refresh, maintenance backup paths, API, requirements, docs, and tests.

## Validation Not Performed Here

This workspace is a GitHub VFS opened from Windows, so Linux-only commands and live service checks were not executed here: `bash -n`, `shellcheck`, `shfmt`, `pytest`, installer dry-run against `/var`, systemd verification, crontab checks, Docker pulls, Pi-hole/Unbound commands, and rescue restore tests. Those are now covered by CI configuration and `docs/ACCEPTANCE_TESTS.md` for a real Linux test host.
