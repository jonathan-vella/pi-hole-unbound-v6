<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

# 🛡️ Pi-hole + Unbound

## **One-Click DNS Security Stack**

[![License](https://img.shields.io/github/license/jonathan-vella/pi-hole-unbound-v6?style=for-the-badge&color=blue)](LICENSE)
[![Pi-hole](https://img.shields.io/badge/Pi--hole-v6.4-red?style=for-the-badge&logo=pihole)](https://pi-hole.net/)
[![Unbound](https://img.shields.io/badge/Unbound-DNS-orange?style=for-the-badge)](https://nlnetlabs.nl/projects/unbound/)
[![Debian](https://img.shields.io/badge/Debian-Bookworm%2FTrixie-red?style=for-the-badge&logo=debian)](https://debian.org/)
[![Python](https://img.shields.io/badge/Python-3.12+-blue?style=for-the-badge&logo=python)](https://python.org/)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-support-FFDD00?logo=buymeacoffee&logoColor=000&style=for-the-badge)](https://buymeacoffee.com/timintech)

<img src="https://skillicons.dev/icons?i=linux,debian,raspberrypi,bash,python,fastapi" alt="Tech Stack" />

**🌐 Languages:** 🇬🇧 English (this file) • [🇩🇪 Deutsch](README.de.md)

</div>
<!-- markdownlint-enable MD033 MD041 -->

---

## ✨ What This Is

A **production-ready installer and management suite** for running Pi-hole + Unbound on a Raspberry Pi.

**DNS chain:**
```
Client → Pi-hole (port 53) → Unbound (port 5335) → Internet
```

Pi-hole handles ad/tracker blocking; Unbound handles recursive DNS resolution with full DNSSEC validation — no third-party DNS resolver required.

---

## ⚡ Quickstart

```bash
git clone https://github.com/jonathan-vella/pi-hole-unbound-v6.git
cd pi-hole-unbound-v6
chmod +x install.sh
sudo ./install.sh
```

> Clone as a **normal user** (`pi`), not root. The installer requires `sudo ./install.sh`.

### Installer Options

| Flag | Description |
|------|-------------|
| `--with-auto-update` | Install automated weekly update system (cron, logrotate, systemd boot check) |
| `--with-netalertx` | Install NetAlertX network monitor (Docker) |
| `--skip-python-api` | Skip the optional Python Suite API |
| `--minimal` | Skip both NetAlertX and Python API |
| `--force` | Force reinstall all components |
| `--dry-run` | Simulate without making changes |
| `--container-mode` | Run Pi-hole in Docker instead of host |
| `--auto-remove-conflicts` | Auto-remove conflicting Docker packages |

---

## ✅ Requirements

| Requirement | Details |
|---|---|
| **Platform** | Raspberry Pi 3/4/5, Debian Bookworm/Trixie (64-bit) |
| **Pi-hole** | v6.x (installed by this script) |
| **Unbound** | Installed and configured to port 5335 |
| **Python** | 3.12+ (for optional Suite API) |
| **User** | Normal user with sudo |

Install prerequisites manually (optional):
```bash
sudo apt-get update
sudo apt-get install -y git curl jq dnsutils iproute2 openssl python3 python3-venv
```

---

## 🔴 Critical: Pi-hole Must Use Unbound as Upstream

> Without this, the stack is broken — DNSSEC is bypassed and you are using an external resolver.

Pi-hole must forward DNS queries to Unbound on **127.0.0.1#5335**.

**Verify via Pi-hole admin → Settings → DNS:**

![Pi-hole upstream DNS setting](docs/assets/pihole-upstream-dns.png)

**Or via the installer / Rescue Menu:**
```bash
sudo pihole-rescue   # Option 9: Pi-hole → Unbound standard fix
```

---

## 🖥️ Management Tools

This repo ships three complementary management interfaces:

### 1. Console Menu (`scripts/console_menu.sh`)

General-purpose interactive menu for everyday management.

```bash
bash ~/pi-hole-unbound-v6/scripts/console_menu.sh
# or with forced text mode:
bash ~/pi-hole-unbound-v6/scripts/console_menu.sh --text
```

![Console Menu](docs/assets/screenshot_console_menu.png)

| Option | Action |
|--------|--------|
| 1 | Post-Install Check (Quick) |
| 2 | Post-Install Check (Full) — requires sudo |
| 3 | Show Service URLs |
| 4 | Manual Steps Guide |
| 5 | Maintenance Pro — requires sudo |
| 6 | View Logs |
| **7** | **Rescue & Backup Menu** |
| 8 | Exit |

---

### 2. Rescue & Backup Menu (`scripts/rescue_menu.sh`)

Standalone recovery and diagnostic tool. Accessible globally:

```bash
sudo pihole-rescue
```

![Rescue Menu](docs/assets/screenshot_rescue_menu.png)

| Option | Action |
|--------|--------|
| 1 | System status check (services, DNS, ports, temperature) |
| 2 | DNS loop / upstream check |
| 3 | Nightly / diagnostic test |
| 4 | Create backup (pihole.toml + Unbound config + systemd drop-ins) |
| 5 | Restore from backup |
| 6 | Delete old backups |
| **7** | **Last-Known-Good restore** |
| **8** | **Emergency DNS bypass** (Pi → 8.8.8.8/1.1.1.1, reversible) |
| **9** | **Pi-hole → Unbound standard fix** |
| 10 | Router / client DNS hint (FritzBox guide) |
| 11 | Show last report / log |
| 0 | Exit |

**System Status:**

![System Status](docs/assets/screenshot_status_check.png)

**DNS Check:**

![DNS Check](docs/assets/screenshot_dns_check.png)

---

### 3. Maintenance Pro (`tools/pihole_maintenance_pro.sh`)

Batch maintenance script (apt updates, Pi-hole update, gravity update, security scan).

```bash
sudo bash tools/pihole_maintenance_pro.sh
# or with flags:
sudo bash tools/pihole_maintenance_pro.sh --no-apt --no-upgrade
```

Available flags: `--no-apt`, `--no-upgrade`, `--no-gravity`, `--restart-ftl`, `--backup`, `--json`

---

### 4. Automated Weekly Update (`scripts/auto_update.sh`)

A hardened unattended update wrapper that runs `pihole_maintenance_pro.sh` on a weekly schedule (default: **Sunday 3 AM**).

**Features:**
- 45-minute execution timeout
- Pre-flight checks: disk space, NTP sync, apt lock detection
- Pre-update config snapshots (`/var/backups/pihole-auto`)
- Unbound config validation with automatic rollback on failure
- DNS health checks (3 retries on port 53 and 5335)
- Major Pi-hole version detection (warns before major upgrades)
- Dual reboot signals: `/var/run/reboot-required` file + kernel mismatch detection
- Reboot blocked when DNS is broken (safety guard)
- Optional webhook notifications via `NOTIFY_URL` environment variable
- Dry-run mode: `DRY_RUN=1 bash scripts/auto_update.sh`

**Enable the auto-update system:**
```bash
# Option A: Use the installer
sudo ./install.sh --with-auto-update

# Option B: Manual setup
# 1. Weekly auto-update cron (Sunday 3 AM)
(sudo crontab -l 2>/dev/null; echo '0 3 * * 0 /home/pi/pi-hole-unbound-v6/scripts/auto_update.sh') | sudo crontab -

# 2. Monthly Unbound root hints refresh
(sudo crontab -l 2>/dev/null; echo '0 4 1 * * curl -sf -o /var/lib/unbound/root.hints.new https://www.internic.net/domain/named.root && mv /var/lib/unbound/root.hints.new /var/lib/unbound/root.hints && systemctl restart unbound') | sudo crontab -

# 3. Logrotate
sudo cp config/logrotate-pihole-auto-update /etc/logrotate.d/pihole-auto-update

# 4. Boot health check service
sudo cp config/pihole-boot-check.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable pihole-boot-check.service

# 5. Required directories
sudo mkdir -p /var/backups/pihole-auto /var/log/pihole-suite
```

**Webhook notifications:**
Set `NOTIFY_URL` to receive alerts on update success/failure:
```bash
export NOTIFY_URL="https://hooks.slack.com/services/..."
```

**Boot health check** (`config/pihole-boot-check.service`):
A systemd oneshot unit that runs `scripts/boot_health_check.sh` after every reboot. It validates Pi-hole and Unbound DNS, auto-restarts services if DNS is down, and writes status to `/var/tmp/pihole_boot_status`.

---

## 📁 Repository Structure

```
pi-hole-unbound-v6/
├── install.sh                     # Main installer
├── start_suite.py                 # Optional REST API (FastAPI/uvicorn)
├── requirements.txt               # Python deps for Suite API
├── .env.example                   # Environment variables template
├── config/
│   ├── logrotate-pihole-auto-update   # Logrotate for auto-update logs
│   └── pihole-boot-check.service      # Systemd oneshot: post-boot DNS check
├── scripts/
│   ├── auto_update.sh             # Hardened weekly auto-update wrapper
│   ├── boot_health_check.sh       # Post-reboot DNS validation
│   ├── console_menu.sh            # Interactive management menu
│   ├── rescue_menu.sh             # Rescue & backup menu (sudo pihole-rescue)
│   ├── post_install_check.sh      # Post-install verification
│   ├── nightly_test.sh            # Nightly DNS/service test
│   ├── repo_selftest.sh           # Repo integrity self-test
│   └── lib/
│       └── ui.sh                  # Shared UI library (colors, log helpers)
├── tools/
│   └── pihole_maintenance_pro.sh  # Batch maintenance script
└── docs/
    ├── CONSOLE_MENU.md            # Full menu documentation
    └── assets/                    # Screenshots
```

---

## ⚙️ Post-Install Verification

```bash
# Quick check (no sudo)
bash scripts/post_install_check.sh --quick

# Full check (requires sudo)
sudo bash scripts/post_install_check.sh --full
```

![Post-Install Check](docs/assets/screenshot_post_install.png)

---

## 🆘 Rescue Operations

### Emergency DNS Bypass
When Pi-hole or Unbound is broken and you have no DNS:

```bash
sudo pihole-rescue  # Option 8: Emergency DNS bypass
```

This sets the Pi itself to use 8.8.8.8/1.1.1.1 directly. **Fully reversible** — the menu stores your previous config and lets you restore it.

### Last-Known-Good Restore
Restores your last known-working backup and verifies DNS is working:

```bash
sudo pihole-rescue  # Option 7: Last-Known-Good restore
```

### Backup / Restore
```bash
sudo pihole-rescue  # Option 4: Create backup
sudo pihole-rescue  # Option 5: Restore from backup
```

Backups are stored in `/home/pi/pihole-rescue-backups/` and include:
- `/etc/pihole/pihole.toml`
- `/etc/unbound/unbound.conf.d/`
- Systemd drop-in files

---

## 🐍 Optional: Suite REST API

`start_suite.py` is an **optional** FastAPI server providing a JSON API for monitoring.

Configure via `.env.example`:
```bash
# Setup
cp .env.example .env
nano .env   # set SUITE_API_KEY

# Install deps
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Start
python3 start_suite.py
# API docs: http://127.0.0.1:8090/docs
```

**Not required** for the core Pi-hole + Unbound stack.

---

## 🌐 Optional: NetAlertX

Network device monitoring (separate install):

```bash
sudo ./install.sh --with-netalertx
```

---

## 🔧 Troubleshooting

### DNS not resolving
```bash
sudo pihole-rescue   # Option 2: DNS check, or Option 8: Emergency bypass
```

### Pi-hole not using Unbound
```bash
sudo pihole-rescue   # Option 9: Pi-hole → Unbound fix
```

### Check system status
```bash
systemctl status pihole-FTL unbound
dig +short @127.0.0.1 google.com
dig +short @127.0.0.1 -p 5335 google.com
```

### Run full diagnostic
```bash
sudo bash scripts/post_install_check.sh --full
sudo bash scripts/nightly_test.sh
```

### Everything is broken
If DNS is completely non-functional and nothing else works:
```bash
sudo pihole-rescue   # Option 8: Emergency DNS bypass (immediate internet access)
sudo pihole-rescue   # Option 7: Last-Known-Good restore (restore + verify)
```

To completely reinstall from scratch:
```bash
sudo ./install.sh --force
```

---

## 🛡️ Security Notes

- The Suite API (`start_suite.py`) binds to **127.0.0.1 only** by default
- Always set a strong `SUITE_API_KEY`
- The Pi-hole admin interface is protected by Pi-hole's own authentication
- Unbound runs on port 5335 (not exposed externally unless you configure it)
- See [SECURITY.md](SECURITY.md) for vulnerability reporting

---

## 📜 License

[MIT License](LICENSE) — © TimInTech
