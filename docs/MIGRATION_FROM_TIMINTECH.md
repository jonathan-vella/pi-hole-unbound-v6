# Migration From TimInTech Pi-hole-Unbound-PiAlert-Setup

Use this guide when an existing Raspberry Pi was installed from `https://github.com/TimInTech/Pi-hole-Unbound-PiAlert-Setup.git` and you want to bring it under this project safely.

Default assumption: the Raspberry Pi is a production DNS host. Start with read-only checks and dry-runs. Do not run destructive restore, uninstall, package upgrade, resolver rewrite, or reboot steps unless you have confirmed a maintenance window and backup.

## Goal

Adopt this project's safer runtime layout, validation scripts, auto-update wrapper, root-hints refresh, rescue menu, and optional Python Suite API without breaking the working Pi-hole + Unbound DNS path.

Expected DNS chain:

```text
clients -> Pi-hole port 53 -> Unbound port 5335 -> Internet
```

## Phase 0: Identify Current State

Run these on the Pi before changing anything:

```bash
hostnamectl
uname -a
systemctl status pihole-FTL unbound --no-pager
sudo crontab -l || true
sudo grep -A5 '^\[dns\]' /etc/pihole/pihole.toml || true
sudo unbound-checkconf
dig +short @127.0.0.1 google.com
dig +short @127.0.0.1 -p 5335 google.com
```

From a client machine, replace `10.20.30.3` with the Pi IP:

```bash
dig @10.20.30.3 google.com
dig @10.20.30.3 dnssec.works
dig @10.20.30.3 dnssec-failed.org
```

Expected: normal domains resolve, `dnssec.works` resolves, and `dnssec-failed.org` fails or returns no usable answer.

## Phase 1: Create Independent Backups

Create backups outside both git checkouts:

```bash
sudo install -d -m 0700 /var/backups/pihole-suite/manual-pre-migration
sudo tar -C / -czf /var/backups/pihole-suite/manual-pre-migration/etc-pihole.tgz etc/pihole
sudo tar -C / -czf /var/backups/pihole-suite/manual-pre-migration/etc-unbound.tgz etc/unbound
sudo crontab -l > /tmp/root-crontab.pre-pihole-suite 2>/dev/null || true
sudo cp /tmp/root-crontab.pre-pihole-suite /var/backups/pihole-suite/manual-pre-migration/root-crontab.pre-pihole-suite 2>/dev/null || true
```

If you use Pi-hole Teleporter, also export from the Pi-hole UI before proceeding.

## Phase 2: Clone This Repo Separately

Do not overwrite the old checkout. Clone this project next to it as the normal user:

```bash
cd ~
git clone https://github.com/jonathan-vella/pi-hole-unbound-v6.git
cd pi-hole-unbound-v6
```

Do not run the installer as a root shell. Use `sudo ./install.sh` from the normal user.

## Phase 3: Run Repo And Dry-Run Checks

If development tools are installed:

```bash
make selftest
```

Then run the installer dry-run:

```bash
sudo ./install.sh --dry-run --with-auto-update
```

Expected: it logs planned work but does not create state, backups, cron entries, systemd units, resolver changes, package/container changes, service restarts, notifications, or reboot.

## Phase 4: Adopt Runtime Tools Without Forcing Reinstall

First try the normal idempotent path:

```bash
sudo ./install.sh --with-auto-update
```

This should install this project's root-owned runtime copies under `/usr/local/lib/pihole-suite`, set up `/etc/pihole-suite/pihole-suite.env`, configure the auto-update/root-hints cron entries, install the boot health service, and preserve existing Pi-hole/Unbound services when already healthy.

Avoid `--force` as the first migration step. Use `--force` only if validation shows stale state or broken config that the normal run does not repair.

## Phase 5: Validate After Migration

```bash
bash scripts/post_install_check.sh --quick
sudo bash scripts/post_install_check.sh --full
systemctl status pihole-FTL unbound pihole-boot-check.service --no-pager
sudo crontab -l
ls -la /usr/local/lib/pihole-suite /usr/local/lib/pihole-suite/scripts/lib /usr/local/bin/pihole-rescue
sudo grep -A5 '^\[dns\]' /etc/pihole/pihole.toml
sudo unbound-checkconf
dig +short @127.0.0.1 google.com
dig +short @127.0.0.1 -p 5335 google.com
```

Expected:

- Pi-hole and Unbound are active.
- Pi-hole upstream includes `127.0.0.1#5335`.
- Cron entries point to `/usr/local/lib/pihole-suite`, not either git checkout.
- `pihole-rescue` points to `/usr/local/lib/pihole-suite/scripts/rescue_menu.sh`.
- `unbound-checkconf` succeeds.

## Phase 6: Validate Safe Automation

Use dry-run first:

```bash
sudo env DRY_RUN=1 bash /usr/local/lib/pihole-suite/scripts/auto_update.sh
sudo env DRY_RUN=1 bash /usr/local/lib/pihole-suite/scripts/root_hints_refresh.sh
```

Only after dry-runs look sane, use live root-hints refresh if desired:

```bash
sudo bash /usr/local/lib/pihole-suite/scripts/root_hints_refresh.sh
sudo grep -q 'A\.ROOT-SERVERS\.NET\.' /var/lib/unbound/root.hints
sudo unbound-checkconf
```

## Phase 7: Retire Old Automation Carefully

Do not delete the old checkout immediately. First inspect for old cron/systemd references:

```bash
sudo crontab -l | grep -E 'TimInTech|Pi-hole-Unbound-PiAlert-Setup|pialert|pihole|unbound' || true
systemctl list-unit-files | grep -Ei 'pihole|unbound|pialert|netalert' || true
```

Remove only duplicate or stale automation after confirming the new `/usr/local/lib/pihole-suite` cron/systemd paths are active. Keep Pi-hole and Unbound themselves installed.

## Rollback Plan

If DNS breaks:

1. Use the rescue menu emergency bypass:

   ```bash
   sudo pihole-rescue
   ```

   Select emergency DNS bypass.

2. Restore manual backups if needed:

   ```bash
   sudo tar -C / -xzf /var/backups/pihole-suite/manual-pre-migration/etc-pihole.tgz
   sudo tar -C / -xzf /var/backups/pihole-suite/manual-pre-migration/etc-unbound.tgz
   sudo systemctl restart unbound pihole-FTL
   ```

3. Re-check DNS:

   ```bash
   dig +short @127.0.0.1 google.com
   dig +short @127.0.0.1 -p 5335 google.com
   ```

## What Not To Do First

- Do not delete the old repo before validating this project's runtime tools.
- Do not start with `sudo ./install.sh --force` unless the normal idempotent run fails to converge.
- Do not remove Pi-hole or Unbound packages.
- Do not run destructive restore/uninstall tests on the production Pi.
- Do not manually edit `/etc/pihole/pihole.toml` while Pi-hole is running unless you understand Pi-hole v6 config behavior.
