# Acceptance Tests

These checks are intended for a disposable Debian/Raspberry Pi OS test host or a VM. Do not run destructive restore tests first on your only production DNS host.

## Installer Dry Run

```bash
sudo ./install.sh --dry-run --with-auto-update --with-netalertx
sudo test ! -e /var/lib/pihole-suite/install.state
sudo test ! -e /etc/systemd/system/pihole-boot-check.service
sudo crontab -l 2>/dev/null | grep -q 'pihole-suite' && exit 1 || true
```

Expected result: the installer logs simulated actions but does not create persistent state, cron entries, systemd units, resolver changes, or backup files.

## Runtime Path Installation

```bash
sudo ./install.sh --with-auto-update
sudo test -x /usr/local/lib/pihole-suite/scripts/auto_update.sh
sudo test -x /usr/local/lib/pihole-suite/scripts/root_hints_refresh.sh
sudo test -x /usr/local/bin/pihole-rescue
systemctl cat pihole-boot-check.service | grep -q '/usr/local/lib/pihole-suite/scripts/boot_health_check.sh'
sudo crontab -l | grep -q '/usr/local/lib/pihole-suite/scripts/auto_update.sh'
sudo crontab -l | grep -q '/usr/local/lib/pihole-suite/scripts/root_hints_refresh.sh'
```

Expected result: unattended jobs point to root-owned runtime copies, not the git checkout.

## Rescue Backup Permissions

```bash
sudo pihole-rescue
sudo find /var/backups/pihole-suite -maxdepth 2 -type d -printf '%m %u:%g %p\n'
sudo find /var/backups/pihole-suite/rescue -type l -print -quit | grep -q . && exit 1 || true
```

Expected result: backup directories are root-owned, mode `0700`, and contain no symlinks.

## Tampered Backup Rejection

```bash
latest_backup=$(sudo find /var/backups/pihole-suite/rescue -maxdepth 1 -mindepth 1 -type d | sort | tail -1)
sudo ln -s /etc/shadow "$latest_backup/tamper-link"
sudo pihole-rescue
sudo rm -f "$latest_backup/tamper-link"
```

Expected result: restore and Last-Known-Good restore reject the backup while the symlink exists.

## Auto-Update Dry Run

```bash
sudo env DRY_RUN=1 bash /usr/local/lib/pihole-suite/scripts/auto_update.sh
sudo test ! -e /var/run/pihole-auto-update.lock
```

Expected result: no snapshots, lock files, status files, service restarts, notifications, maintenance execution, or reboot occur.

## Root Hints Refresh

```bash
sudo env DRY_RUN=1 bash /usr/local/lib/pihole-suite/scripts/root_hints_refresh.sh
sudo bash /usr/local/lib/pihole-suite/scripts/root_hints_refresh.sh
sudo grep -q 'A\.ROOT-SERVERS\.NET\.' /var/lib/unbound/root.hints
```

Expected result: dry-run is side-effect-free; live run installs a validated root hints file and reloads/restarts Unbound only after validation.

## Auto-Update Snapshot Retention

```bash
sudo env PIHOLE_AUTO_BACKUP_RETENTION=2 bash /usr/local/lib/pihole-suite/scripts/auto_update.sh
sudo find /var/backups/pihole-suite/auto-update -maxdepth 1 -mindepth 1 -type d | wc -l
```

Expected result: timestamped snapshots are created and old snapshots are pruned to the configured retention count.

## Optional API Smoke Test

```bash
api_key=$(sudo awk -F= '/^SUITE_API_KEY=/{print $2}' /etc/pihole-suite/pihole-suite.env)
curl -sf -H "X-API-Key: $api_key" http://127.0.0.1:8090/health
curl -sf -H "X-API-Key: $api_key" 'http://127.0.0.1:8090/dns?limit=5'
```

Expected result: authenticated endpoints return JSON and large log files are tailed rather than loaded in full.
