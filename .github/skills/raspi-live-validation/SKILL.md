---
name: raspi-live-validation
description: 'Safely validate the production Raspberry Pi 4 Pi-hole + Unbound host. Use when: checking live DNS, systemd, cron, root-owned runtime files, auto-update, root hints, Python API, or post-install health without destructive changes.'
argument-hint: 'host/user or focus area, e.g. 10.20.30.3 DNS smoke, root hints, API health'
---

# Raspberry Pi Live Validation

Use this skill for non-destructive validation of the user's real Raspberry Pi 4 DNS host. The default posture is production-safe: observe first, dry-run before live mutation, and ask before any remote access.

## Default Host Profile

- Hardware/OS: Raspberry Pi 4, Debian/Raspberry Pi OS aarch64, Linux `raspi4 6.12.75+rpt-rpi-v8` or similar.
- DNS stack: host Pi-hole v6 on port 53 forwarding to host Unbound on port 5335.
- Enabled priorities: auto-update, root hints refresh, boot health check, optional Python Suite API.
- Not default priority: NetAlertX and container Pi-hole unless the user asks.

## Safety Rules

- Ask for SSH host/user before remote commands. Do not assume credentials.
- Start with client-side DNS checks and read-only host checks.
- Use `--dry-run` or `DRY_RUN=1` before any workflow that could mutate state.
- Do not run restore, uninstall, package upgrade, Docker mutation, resolver rewrite, reboot, or service-changing commands on production unless the user explicitly confirms that exact operation.
- Do not print secrets from `/etc/pihole-suite/pihole-suite.env`; redact API keys and webhook URLs.

## Decision Flow

1. If no host/user is provided, give local/client-side commands and ask for SSH details only if remote validation is needed.
2. If validating from a client machine, use `dig @<pihole-ip>` checks first.
3. If validating over SSH, use read-only commands first: service status, config inspection, cron listing, file listing, and API smoke tests.
4. If a check requires mutation, convert it to dry-run if supported.
5. If destructive validation is required, recommend a disposable Debian/Raspberry Pi OS host or VM.

## Client-Side DNS Smoke Test

Replace `10.20.30.3` with the Pi-hole IP:

```bash
dig @10.20.30.3 google.com
dig @10.20.30.3 pi-hole.net
dig @10.20.30.3 dnssec.works
dig @10.20.30.3 dnssec-failed.org
```

Expected:

- Normal domains resolve.
- `dnssec.works` resolves.
- `dnssec-failed.org` fails or returns no usable answer.
- Admin UI is reachable at `http://10.20.30.3/admin`.

## Read-Only Host Checks

Over SSH, ask for the username and host first. Then use commands like:

```bash
hostnamectl
uname -a
systemctl status pihole-FTL unbound pihole-boot-check.service --no-pager
sudo crontab -l
ls -la /usr/local/lib/pihole-suite /usr/local/lib/pihole-suite/scripts /usr/local/lib/pihole-suite/scripts/lib
ls -la /usr/local/bin/pihole-rescue
sudo grep -A5 '^\[dns\]' /etc/pihole/pihole.toml
sudo unbound-checkconf
dig +short @127.0.0.1 google.com
dig +short @127.0.0.1 -p 5335 google.com
```

Expected:

- Pi-hole and Unbound services are active or failures are clearly explained.
- Runtime automation points to `/usr/local/lib/pihole-suite`, not a git checkout.
- Pi-hole upstream includes `127.0.0.1#5335`.
- `unbound-checkconf` passes.

## Safe Dry-Run Checks

Use dry-run for workflows that would normally mutate state:

```bash
cd ~/pi-hole-unbound-v6
sudo ./install.sh --dry-run --with-auto-update
sudo env DRY_RUN=1 bash /usr/local/lib/pihole-suite/scripts/auto_update.sh
sudo env DRY_RUN=1 bash /usr/local/lib/pihole-suite/scripts/root_hints_refresh.sh
```

Expected:

- No persistent state, backups, cron/systemd edits, resolver changes, service restarts, notifications, or reboot.

## Optional API Smoke Test

If the Python Suite API is enabled, avoid printing the key. Use a redacted flow:

```bash
api_key=$(sudo awk -F= '/^SUITE_API_KEY=/{print $2}' /etc/pihole-suite/pihole-suite.env)
curl -sf -H "X-API-Key: $api_key" http://127.0.0.1:8090/health
curl -sf -H "X-API-Key: $api_key" 'http://127.0.0.1:8090/dns?limit=5'
unset api_key
```

When reporting output, do not include the API key.

## Completion Output

End with:

- Host/IP and whether SSH was used.
- Checks run and results.
- Any production-safe issues found.
- Checks intentionally not run because they are destructive or require confirmation.
- Recommended next step, separating production-safe actions from disposable-host tests.
