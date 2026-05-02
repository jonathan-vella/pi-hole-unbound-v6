# Project Optimization Plan

This plan turns the project review into actionable work items for the Pi-hole + Unbound suite. It is organized by priority so reliability and maintainability improvements land before polish work.

## Goals

- Improve confidence in installer, rescue, update, and API changes.
- Reduce duplicate shell and parsing logic across scripts.
- Make production deployments more predictable.
- Keep user-facing documentation aligned with actual behavior.
- Make dry-run behavior strictly side-effect free.
- Store root-run backups under a protected system path by default.
- Avoid unattended root execution from user-writable repository paths.
- Define compatibility, release, recovery, and observability expectations before implementation.

## Required Decisions

- `--dry-run` must be a pure simulation. It must not write installer state, create files, change permissions, install cron/systemd entries, alter resolver configuration, or mark any component as OK.
- Resume/state priming must not be hidden inside `--dry-run`. If a future workflow needs this, add a separate explicit flag such as `--prepare-state`.
- Root-run backups must default to `/var/backups/pihole-suite`, not `/home/pi`.
- Backup directories must be owned by `root:root` and created with `0700` permissions.
- Existing `/home/pi/pihole-rescue-backups` backups may be discovered or imported for compatibility, but new backups should use `/var/backups/pihole-suite/rescue`.
- Cron, systemd, and globally installed rescue commands must run root-owned installed copies, not scripts directly from a user-writable git checkout.
- The git checkout is source material. Runtime code should be installed under a root-owned system path such as `/usr/local/lib/pihole-suite`.
- Suite-created runtime state, logs, configuration, and backups should live under `/var/lib/pihole-suite`, `/var/log/pihole-suite`, `/etc/pihole-suite`, and `/var/backups/pihole-suite`.
- Any uninstall or disable workflow must avoid removing Pi-hole or Unbound unless the user explicitly requests destructive removal.

## Compatibility Targets To Define

Before implementing the plan, document the exact supported environment matrix. Do not infer support for platforms that are not tested.

- Debian releases: Bookworm and Trixie, or the exact subset the maintainer intends to support.
- Raspberry Pi OS releases and architectures: define whether 32-bit, 64-bit, or both are supported.
- Pi-hole version: define whether this suite supports Pi-hole v6 only.
- Install modes: define support level for host mode and container mode separately.
- Init system: define whether systemd is required for full functionality.
- Python version: align the minimum version with `README.md`, `requirements.txt`, and CI.
- Docker support: define whether Docker is optional, required only for NetAlertX/container mode, or unsupported on some targets.

## Security Boundaries

- Treat the repository checkout as user-writable source code, not a trusted runtime path for unattended root jobs.
- Treat `/etc/pihole-suite/pihole-suite.env` and any environment files as secret-bearing configuration.
- Treat backups as untrusted until ownership, permissions, symlinks, and expected file layout have been validated.
- Treat webhook URLs as sensitive because they may contain tokens.
- Treat restore, resolver modification, cron installation, systemd installation, Docker operations, and package operations as privileged state-changing actions that must not run during dry-run.

## Do-Not-Break Invariants

- Never mark installer state as OK during `--dry-run`.
- Never leave `/etc/resolv.conf` worse than before if a step fails.
- Never delete live Unbound config before a replacement or rollback has been validated.
- Never restore backup content containing symlinks or unsafe permissions.
- Never run unattended root jobs from user-writable files.
- Never print API keys, webhook tokens, or full secret-bearing environment files.
- Never reboot after auto-update if DNS is broken or a major Pi-hole upgrade requires manual review.
- Never let stale installer state override live-system validation.

## Release Strategy

- Implement the plan in small pull requests grouped by phase or risk area.
- Update `CHANGELOG.md` for each merged phase.
- Mark backup path migration and root-owned runtime copy behavior as user-visible changes.
- Test each state-changing phase on a disposable Debian/Raspberry Pi host before merging the next state-changing phase.
- Avoid a single large release that changes installer state, backup layout, cron/systemd behavior, and rescue restore behavior at once.

## Phase 1: CI And Quality Gates

### 1. Add GitHub Actions CI

**Why:** Dependabot is configured, but there is no workflow enforcing repository checks on pull requests.

**Tasks:**

- Add `.github/workflows/ci.yml`.
- Run Bash syntax checks for every shell script.
- Run `scripts/repo_selftest.sh`.
- Run `shellcheck -x` with the existing `.shellcheckrc`.
- Run `shfmt -d` as a formatting check.
- Run `python -m py_compile start_suite.py`.
- Install `requirements-dev.txt` and run `ruff check .`.
- Run `pytest` once tests are added.

**Acceptance Criteria:**

- Pull requests fail when shell syntax, ShellCheck, shfmt, Python syntax, Ruff, or tests fail.
- CI works without requiring Pi-hole, Unbound, Docker, or root privileges.

### 2. Add Python Tool Configuration

**Why:** `ruff` and `pytest` are dependencies, but there is no checked-in configuration for consistent local and CI behavior.

**Tasks:**

- Add `pyproject.toml` with Ruff and pytest settings.
- Target the same Python version documented in `README.md`.
- Exclude generated runtime directories such as `data/` and virtual environments.

**Acceptance Criteria:**

- `ruff check .` runs consistently locally and in CI.
- `pytest` discovers only intentional tests.

### 3. Add Dry-Run Regression Tests

**Why:** The installer currently treats dry-run as a preview, but dry-run paths can still mutate installer state. This can poison future real installs.

**Tasks:**

- Add tests or scripted checks proving `sudo ./install.sh --dry-run` does not modify persistent state.
- Verify dry-run does not call `update_state` for `PACKAGES_OK`, `UNBOUND_OK`, `PIHOLE_OK`, `NETALERTX_OK`, `PY_SUITE_OK`, or `HEALTH_OK`.
- Verify dry-run does not create or modify `/var/lib/pihole-suite`, `/etc/pihole-suite`, `/var/log/pihole-suite`, cron entries, systemd units, Docker containers, or `/etc/resolv.conf`.
- Mock or stub privileged commands in CI so the test can run without root.

**Acceptance Criteria:**

- Dry-run tests fail if any persistent file or state flag is changed.
- CI covers the dry-run contract without requiring a live Pi-hole host.

## Phase 2: Installer Safety And State Semantics

### 4. Make `--dry-run` Pure Simulation

**Why:** `--dry-run` should build trust before changing DNS/system services. It must not prime resume state or mark simulated steps as complete.

**Tasks:**

- Prevent `update_state` from writing any OK flags during dry-run.
- Skip real health checks during dry-run and print what would be checked instead.
- Avoid creating env files, log/state directories, backups, cron entries, systemd unit changes, resolver changes, Docker containers, virtual environments, or package installs during dry-run.
- Make dry-run output clear about simulated versus skipped checks.
- Keep `--resume` as a no-op compatibility alias unless a separate explicit state-preparation workflow is added.

**Acceptance Criteria:**

- Running `sudo ./install.sh --dry-run` twice produces no persistent system changes.
- A later real install cannot skip work because a previous dry-run marked state as complete.
- Invalid arguments and unsupported OS checks may still fail early, but no installer state is written.

### 5. Harden Installer State Handling

**Why:** Installer state is an optimization, not an authority. Stale or poisoned state can skip required work on live DNS infrastructure.

**Tasks:**

- Treat the state file as advisory only.
- On `--force`, reset or ignore all component OK flags before running steps.
- Validate every component against the live system before skipping it.
- Add clear logging when a state flag is ignored or reset.

**Acceptance Criteria:**

- `--force` cannot skip package, Unbound, Pi-hole, Python suite, NetAlertX, or health-check work because of stale state.
- Manual removal of a component causes the next installer run to repair it or fail loudly.

### 6. Escape Or Regenerate Systemd Unit Writes

**Why:** Rewriting `ExecStart` with an unescaped repository path can corrupt the unit if the path contains sed replacement metacharacters.

**Tasks:**

- Stop using direct `sed` replacement with raw `SCRIPT_DIR` for `pihole-boot-check.service`.
- Generate the installed unit from a safe heredoc/template, or escape all sed replacement metacharacters before substitution.
- Validate the generated unit with `systemd-analyze verify` when available.

**Acceptance Criteria:**

- Install works from paths containing spaces, `&`, `#`, and other shell/sed-sensitive characters.
- The installed unit has the exact intended `ExecStart` path.

### 7. Install Root-Owned Runtime Copies

**Why:** Cron, systemd, and global rescue commands run with elevated privileges. They should not execute scripts from a normal user's editable git checkout.

**Tasks:**

- Install suite runtime scripts under `/usr/local/lib/pihole-suite` with `root:root` ownership.
- Install global commands such as `pihole-rescue` as root-owned wrappers or symlinks that point only to root-owned runtime copies.
- Point cron entries and systemd units at installed runtime copies, not `$SCRIPT_DIR` inside the checkout.
- Keep `/etc/pihole-suite/pihole-suite.env` as the environment/config entry point for unattended jobs.
- Add an installer check that warns if an existing cron/systemd entry still points to a user home or repository checkout.
- Document how users update installed runtime copies after pulling a new repo version.

**Acceptance Criteria:**

- `systemctl cat pihole-boot-check.service` shows an `ExecStart` path under `/usr/local/lib/pihole-suite` or another documented root-owned runtime path.
- Root crontab entries for this suite call root-owned installed scripts.
- A normal user editing the git checkout cannot change code that cron/systemd will execute as root until the installer explicitly updates the installed runtime copy.

### 8. Add Disable And Uninstall Workflows

**Why:** Users need a controlled way to remove suite-created cron/systemd glue without accidentally deleting Pi-hole, Unbound, or backups.

**Tasks:**

- Add `--disable-auto-update` to remove or disable suite-created cron entries and boot health service.
- Add `--uninstall-suite-tools` to remove installed suite wrappers, runtime copies, systemd units, and cron entries after confirmation.
- Preserve `/etc/pihole-suite`, `/var/lib/pihole-suite`, `/var/log/pihole-suite`, and `/var/backups/pihole-suite` unless the user explicitly confirms data removal.
- Do not uninstall Pi-hole, Unbound, Docker, or NetAlertX by default.
- Document uninstall/disable scope clearly in README files.

**Acceptance Criteria:**

- Users can disable unattended updates without editing crontab manually.
- Users can remove suite-created runtime glue while preserving DNS services and backups.
- Destructive cleanup requires an explicit confirmation flag or prompt.

## Phase 3: Backup And Restore Safety

### 9. Move Backups To `/var/backups/pihole-suite`

**Why:** Rescue, maintenance, and auto-update backups are root-managed system recovery assets and should not default to a user home directory.

**Tasks:**

- Define `BACKUP_ROOT="${PIHOLE_BACKUP_ROOT:-/var/backups/pihole-suite}"`.
- Use `/var/backups/pihole-suite/rescue` for rescue backups.
- Use `/var/backups/pihole-suite/auto-update` for auto-update snapshots.
- Use `/var/backups/pihole-suite/maintenance` for maintenance backups.
- Create backup roots as `root:root` with `0700` permissions.
- Keep `PIHOLE_BACKUP_DIR` as an advanced override for rescue backups.
- Detect existing `/home/pi/pihole-rescue-backups` and offer read-only discovery or import during a transition period.

**Acceptance Criteria:**

- New backups are created under `/var/backups/pihole-suite` by default.
- Backup paths are documented consistently in `README.md`, `README.de.md`, and `docs/CONSOLE_MENU.md`.
- Existing users with old home-directory backups get a clear migration path.

### 10. Harden Restore And Delete Operations

**Why:** Restore operations copy data into `/etc` as root. Every restore path needs the same tamper checks and serialization.

**Tasks:**

- Apply symlink rejection to both normal restore and Last-Known-Good restore.
- Reject backups with unsafe ownership or world/group-writable directories.
- Add a lock file with `flock` around backup create, restore, delete, and Last-Known-Good operations.
- Restore into temporary paths first where practical, then move into place after validation.
- Preserve file ownership and permissions intentionally.
- Exclude secret-bearing env files from backups unless the user explicitly requests them.

**Acceptance Criteria:**

- Last-Known-Good restore cannot bypass backup tamper checks.
- Concurrent rescue menu sessions cannot restore/delete the same backup at the same time.
- Tampered backups fail closed before any `/etc` file is modified.
- Rescue backups do not silently include API keys or webhook tokens.

### 11. Make Auto-Update Rollback Atomic

**Why:** Auto-update currently restores Unbound config after deleting the live config directory. A failed copy can leave DNS without its config.

**Tasks:**

- Restore Unbound snapshots into a temporary directory first.
- Validate restored config with `unbound-checkconf` before replacing live files.
- Swap/copy into place only after validation succeeds.
- Keep the previous live directory until the replacement is known good.
- Add retention for `/var/backups/pihole-suite/auto-update` snapshots.

**Acceptance Criteria:**

- Failed rollback leaves the existing live Unbound config intact.
- Snapshot retention prevents unbounded disk growth on small SD cards.

## Phase 4: Tests And API Reliability

### 12. Add Tests For `start_suite.py`

**Why:** The optional API contains important health and parsing behavior but currently has no test coverage.

**Tasks:**

- Add tests for API key authentication.
- Add tests for `/health`, `/version`, `/urls`, `/pihole`, `/unbound`, `/dns`, `/leases`, and `/stats`.
- Mock subprocess calls used by `_run()`.
- Mock file reads for Pi-hole logs and DHCP leases.
- Test failure paths for missing commands, missing files, and timed-out commands.

**Acceptance Criteria:**

- Tests run without Pi-hole, Unbound, systemd, or root privileges.
- Auth failures return `401`.
- Missing `SUITE_API_KEY` returns a server configuration error.
- Parser tests cover empty files, malformed lines, and valid sample lines.

### 13. Add Typed API Response Models

**Why:** The API currently returns raw dictionaries, while `pydantic` is already listed as a dependency.

**Tasks:**

- Define Pydantic models for health, version, URLs, Pi-hole status, Unbound status, NetAlertX status, DNS log entries, DHCP leases, and stats.
- Attach `response_model` to FastAPI routes.
- Keep response fields stable and documented by FastAPI OpenAPI output.

**Acceptance Criteria:**

- API responses validate against declared models.
- OpenAPI docs show structured schemas for every endpoint.
- Existing JSON shape remains backward compatible unless a breaking change is documented.

### 14. Bound API File Reads And Expensive Checks

**Why:** The API reads log and lease files on request. Large files should not be loaded wholesale for every call.

**Tasks:**

- Replace full-file `readlines()` with a bounded tail reader.
- Keep `/dns`, `/leases`, and `/stats` limits conservative.
- Add short TTL caching for expensive derived stats.
- Add tests for large files, missing files, malformed lines, and limit clamping.

**Acceptance Criteria:**

- API requests do not load unbounded log files into memory.
- Limit handling is tested and documented.

## Phase 5: Shared Helpers And Parsing Cleanup

### 15. Centralize Pi-hole Upstream Handling

**Why:** Pi-hole v6 upstreams are parsed and written by several different regex, `sed`, `awk`, and Python snippets.

**Tasks:**

- Create one shared shell helper for reading and validating Pi-hole upstreams.
- Prefer `pihole-FTL --config dns.upstreams` or `pihole --config dns.upstreams` where available.
- Keep a tested fallback for reading `/etc/pihole/pihole.toml`.
- For Python reads, use `tomllib` on Python 3.11+ instead of regex.
- Update `install.sh`, `scripts/post_install_check.sh`, `scripts/rescue_menu.sh`, and `start_suite.py` to use the shared approach.

**Acceptance Criteria:**

- Multiline TOML arrays are handled correctly.
- Existing comments are not unnecessarily destroyed by write operations.
- Invalid upstream values are rejected before being passed to Pi-hole commands.
- Installer, rescue menu, post-install check, and API agree on the detected upstream.
- Generated Pi-hole TOML is validated before replacing the live file.
- Failed validation rolls back to the previous config.

### 16. Centralize DNS And Service Health Checks

**Why:** DNS checks and service checks are repeated across installer, auto-update, boot health check, post-install check, rescue menu, and maintenance scripts.

**Tasks:**

- Add `scripts/lib/health.sh`.
- Include helpers such as `health_dns_check`, `health_wait_for_dns`, `health_service_active`, and `health_detect_unbound_port`.
- Replace duplicated logic in `install.sh`, `scripts/auto_update.sh`, `scripts/boot_health_check.sh`, `scripts/post_install_check.sh`, and `scripts/rescue_menu.sh`.

**Acceptance Criteria:**

- DNS timeout, retries, test domain, and expected response logic are consistent.
- Existing scripts preserve their current user-facing behavior.
- ShellCheck remains clean after sourcing the new helper.

## Phase 6: Deployment Predictability

### 17. Make Container Images Configurable And Pinned

**Why:** `latest` image tags can change unexpectedly and break DNS or monitoring deployments.

**Tasks:**

- Add `PIHOLE_IMAGE` and `NETALERTX_IMAGE` environment variables.
- Default to documented stable tags instead of `latest`, or document why `latest` remains the default.
- Print selected image names during installation.
- Document production guidance for semver tags or digests.

**Acceptance Criteria:**

- Users can override image names without editing `install.sh`.
- Re-running the installer uses the configured image consistently.
- README examples mention image override variables.

### 18. Harden Root Hints Refresh

**Why:** Root hints are downloaded during install and refreshed by cron; both paths should validate before replacing the active file.

**Tasks:**

- Download to a temporary file in the same filesystem.
- Require non-empty content.
- Validate expected root-zone content.
- Preserve ownership and permissions.
- Move into place atomically.
- Restart Unbound only after validation succeeds.
- Update README manual cron examples to match the safer installer behavior.

**Acceptance Criteria:**

- Failed downloads leave the existing `root.hints` untouched.
- Invalid downloaded content is removed.
- Installer and documentation use the same refresh logic.

### 19. Avoid Unnecessary Installer Backup Churn

**Why:** `configure_pihole_v6_toml_upstreams()` creates a backup before confirming whether a change is needed.

**Tasks:**

- Move the fast-path upstream check before creating a timestamped backup.
- Create backups only when `pihole.toml` will be modified.
- Consider pruning old installer-created `pihole.toml.backup.*` files or documenting retention.

**Acceptance Criteria:**

- Re-running `install.sh` when upstreams are already correct does not create a new backup.
- A backup is still created before every actual TOML modification.

### 20. Persist Unattended Notification Configuration

**Why:** `NOTIFY_URL` is documented as an environment variable, but cron and systemd boot checks do not inherit a user shell export.

**Tasks:**

- Store notification settings in `/etc/pihole-suite/pihole-suite.env` or a dedicated root-readable config file.
- Make auto-update cron source the config safely before running.
- Add `EnvironmentFile=-/etc/pihole-suite/pihole-suite.env` to the boot health check systemd unit.
- Keep validation for HTTP(S) URLs and document any private-network webhook behavior.

**Acceptance Criteria:**

- `NOTIFY_URL` works for cron-triggered auto-update runs.
- `NOTIFY_URL` works for boot health check runs after reboot.
- Secrets are not printed in full in logs or installer output.

### 21. Standardize Logs And Status Files

**Why:** Users and external monitors need stable, parseable signals for install, update, boot health, and rescue results.

**Tasks:**

- Define expected log files under `/var/log/pihole-suite`.
- Define expected status files such as `/var/tmp/pihole_update_status` and `/var/tmp/pihole_boot_status`.
- Standardize status values and timestamps, for example `<epoch> OK ...` and `<epoch> FAIL ...`.
- Ensure status files do not include secrets.
- Document status files and log locations in README and console menu docs.

**Acceptance Criteria:**

- Auto-update and boot health status files use consistent machine-readable formats.
- Logs and status files can be consumed by external monitoring without parsing colored terminal output.

### 22. Add Manual Disaster-Recovery Acceptance Tests

**Why:** CI can mock script behavior, but recovery workflows must also be proven on a disposable host.

**Tasks:**

- Document a manual test that intentionally breaks Pi-hole upstream config, runs the standard fix, and verifies Pi-hole forwards to Unbound again.
- Document a manual test that intentionally breaks Unbound config, restores from backup, and verifies DNS works again.
- Document a manual test that activates emergency DNS bypass, verifies `apt`/`curl` work, restores the previous resolver, and verifies local DNS again.
- Record expected commands, expected output, rollback steps, and cleanup steps.

**Acceptance Criteria:**

- A maintainer can validate the rescue story end to end on a disposable host before release.
- Recovery tests include both failure injection and cleanup.

## Phase 7: Documentation And User-Facing Accuracy

### 23. Fix Stale Commands And Paths

**Why:** Some user-facing paths and commands are stale or host-specific.

**Tasks:**

- Replace the final installer hint `./check.sh` with the existing post-install check command.
- Avoid hardcoded `/home/pi/pi-hole-unbound-v6` in README cron examples, or clearly mark it as an example path.
- Replace the documented default rescue backup path `/home/pi/pihole-rescue-backups` with `/var/backups/pihole-suite/rescue`.
- Document old `/home/pi/pihole-rescue-backups` as a legacy migration path only.
- Update `README.md`, `README.de.md`, and `docs/CONSOLE_MENU.md` together.

**Acceptance Criteria:**

- Every documented command maps to a file that exists in the repo or a globally installed command created by the installer.
- Backup path documentation matches script defaults.
- English and German README files remain aligned.

### 24. Document Configuration Variables

**Why:** Several behaviors are already configurable through environment variables, but they are spread across scripts and docs.

**Tasks:**

- Document `SUITE_API_KEY`, `SUITE_PORT`, `SUITE_HOST`, `SUITE_DATA_DIR`, `SUITE_LOG_LEVEL`, `UNBOUND_PORT`, `NETALERTX_PORT`, `NOTIFY_URL`, `DRY_RUN`, `DNS_TEST_DOMAIN`, `PIHOLE_BACKUP_ROOT`, and `PIHOLE_BACKUP_DIR`.
- Add any new image variables from Phase 6.
- Include examples for installer, auto-update, boot health check, and rescue menu usage.
- Clearly state that `--dry-run` is side-effect free and does not prepare resume state.
- Document the root-owned runtime install path and explain that cron/systemd do not execute directly from the git checkout.

**Acceptance Criteria:**

- `.env.example`, README files, and scripts agree on variable names and defaults.
- Sensitive values such as API keys are never printed in full.

### 25. Document Shell And Config-Write Rules

**Why:** The repo is shell-heavy and edits privileged config files. Contributors need clear rules to avoid reintroducing unsafe patterns.

**Tasks:**

- Document that scripts target Bash, not POSIX `sh`.
- Forbid `eval` in suite scripts unless separately reviewed and justified.
- Prefer command arrays or carefully quoted commands over shell string execution.
- Require temp-file plus validation plus atomic move for privileged config writes.
- Require escaping for paths used in `sed`, systemd units, cron entries, and generated config files.
- Require `flock` for stateful root operations that can conflict.

**Acceptance Criteria:**

- Contributor documentation explains the shell safety baseline.
- CI checks support the documented shell and formatting rules where practical.

## Phase 8: Dependency And Maintenance Cleanup

### 26. Trim Or Use Unused Python Dependencies

**Why:** Smaller dependency sets reduce install time and security update noise.

**Tasks:**

- Check whether `requests`, `httpx`, `colorlog`, and direct `pydantic` usage are needed.
- Remove unused packages from `requirements.txt`, or update code to use them intentionally.
- Keep `requirements-dev.txt` focused on development-only tools.

**Acceptance Criteria:**

- `pip install -r requirements.txt` installs only runtime dependencies.
- Dependabot groups still match the final dependency list.

### 27. Add Developer Convenience Commands

**Why:** Contributors should not need to memorize CI commands.

**Tasks:**

- Add a lightweight `Makefile` or `justfile` with `lint`, `test`, `selftest`, and `format-check` targets.
- Ensure commands match CI behavior.
- Document the commands in README or a short contributor section.

**Acceptance Criteria:**

- One local command runs the same checks as CI where possible.
- Commands work on Debian-like systems without requiring root for repo-only checks.

## Suggested Implementation Order

1. Make `--dry-run` side-effect free and add regression coverage.
2. Install root-owned runtime copies and stop unattended root execution from the checkout.
3. Move backup defaults to `/var/backups/pihole-suite` and harden restore paths.
4. Make auto-update rollback atomic.
5. Add CI workflow and Python tool configuration.
6. Add API tests, typed response models, and bounded API file reads.
7. Add shared health helpers.
8. Centralize Pi-hole upstream handling and validate TOML writes.
9. Fix systemd unit generation, uninstall/disable workflows, and notification persistence.
10. Fix installer backup churn.
11. Standardize logs/status files and add manual disaster-recovery tests.
12. Make container images configurable.
13. Harden root hints refresh.
14. Update documentation paths, commands, variables, compatibility targets, shell rules, and migration notes.
15. Trim dependencies and add developer convenience commands.

## Validation Checklist

Before merging the full optimization series, run:

```bash
bash scripts/repo_selftest.sh
bash scripts/nightly_test.sh
python3 -m py_compile start_suite.py
ruff check .
pytest
shellcheck -x install.sh scripts/*.sh scripts/lib/*.sh tools/*.sh
shfmt -d .
```

For changes touching installer or live-system behavior, also validate on a disposable Debian/Raspberry Pi test host:

```bash
sudo ./install.sh --dry-run --resume
test ! -f /var/lib/pihole-suite/install.state || ! sudo grep -Eq '^(PACKAGES_OK|UNBOUND_OK|PIHOLE_OK|NETALERTX_OK|PY_SUITE_OK|HEALTH_OK)=true$' /var/lib/pihole-suite/install.state
sudo ./install.sh --minimal
bash scripts/post_install_check.sh --quick
sudo bash scripts/post_install_check.sh --full
sudo env DRY_RUN=1 bash scripts/auto_update.sh
sudo bash scripts/boot_health_check.sh
```

For auto-update and root-owned runtime-copy changes, validate the opt-in installation path separately:

```bash
sudo ./install.sh --minimal --with-auto-update
systemctl cat pihole-boot-check.service | grep -q '/usr/local/lib/pihole-suite'
sudo crontab -l | grep 'pihole' | grep -q '/usr/local/lib/pihole-suite'
```

For backup and restore changes, validate on a disposable host only:

```bash
sudo PIHOLE_BACKUP_ROOT=/var/backups/pihole-suite bash scripts/rescue_menu.sh
sudo find /var/backups/pihole-suite -maxdepth 2 -type d -printf '%m %u:%g %p\n'
sudo find /var/backups/pihole-suite -type l -print -quit | grep -q . && exit 1 || true
```

For manual recovery validation, document and run these scenarios on a disposable host:

```bash
# Break Pi-hole upstream, run standard fix, verify Pi-hole -> Unbound.
# Break Unbound config, restore from backup, verify DNS.
# Activate emergency DNS bypass, verify apt/curl, restore resolver, verify local DNS.
```

## Notes

- Keep changes small and staged by phase; many of these tasks touch shared operational behavior.
- Prefer read-only tests and mocks for CI.
- Use a real disposable Pi-hole host only for integration validation.
- Do not use dry-run to prepare state. If state preparation is ever needed, add and document a separate explicit command.
- Keep compatibility claims tied to tested targets only.
- Prefer root-owned installed runtime copies for unattended jobs, even if the repo checkout remains useful for development.