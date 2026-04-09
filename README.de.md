<div align="center">

# 🛡️ Pi-hole + Unbound

## **Ein-Klick DNS-Sicherheits-Stack**

[![License](https://img.shields.io/github/license/jonathan-vella/pi-hole-unbound-v6?style=for-the-badge&color=blue)](LICENSE)
[![Pi-hole](https://img.shields.io/badge/Pi--hole-v6.4-red?style=for-the-badge&logo=pihole)](https://pi-hole.net/)
[![Unbound](https://img.shields.io/badge/Unbound-DNS-orange?style=for-the-badge)](https://nlnetlabs.nl/projects/unbound/)
[![Debian](https://img.shields.io/badge/Debian-Bookworm%2FTrixie-red?style=for-the-badge&logo=debian)](https://debian.org/)
[![Python](https://img.shields.io/badge/Python-3.12+-blue?style=for-the-badge&logo=python)](https://python.org/)
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-support-FFDD00?logo=buymeacoffee&logoColor=000&style=for-the-badge)](https://buymeacoffee.com/timintech)

<img src="https://skillicons.dev/icons?i=linux,debian,raspberrypi,bash,python,fastapi" alt="Tech Stack" />

**🌐 Sprachen:** 🇩🇪 Deutsch (diese Datei) • [🇬🇧 English](README.md)

</div>

---

## ✨ Worum es geht

Ein **produktionsbereiter Installer und Management-Suite** für Pi-hole + Unbound auf dem Raspberry Pi.

**DNS-Kette:**
```
Client → Pi-hole (Port 53) → Unbound (Port 5335) → Internet
```

Pi-hole blockiert Werbung und Tracker. Unbound löst DNS-Anfragen rekursiv auf — ohne externen DNS-Resolver, mit vollständiger DNSSEC-Validierung.

---

## ⚡ Schnellstart

```bash
git clone https://github.com/jonathan-vella/pi-hole-unbound-v6.git
cd pi-hole-unbound-v6
chmod +x install.sh
sudo ./install.sh
```

> Als **normaler Nutzer** klonen (z.B. `pi`), nicht als root. Der Installer wird via `sudo ./install.sh` ausgeführt.

### Installer-Optionen

| Flag | Beschreibung |
|------|-------------|
| `--with-auto-update` | Automatisches wöchentliches Update-System installieren (Cron, Logrotate, Systemd) |
| `--with-netalertx` | NetAlertX Netzwerk-Monitor installieren (Docker) |
| `--skip-python-api` | Optionale Python Suite API überspringen |
| `--minimal` | Sowohl NetAlertX als auch Python API überspringen |
| `--force` | Neuinstallation aller Komponenten erzwingen |
| `--dry-run` | Simulation ohne Änderungen |
| `--container-mode` | Pi-hole in Docker statt auf dem Host |
| `--auto-remove-conflicts` | Konfliktierende Docker-Pakete automatisch entfernen |

---

## ✅ Voraussetzungen

| Anforderung | Details |
|---|---|
| **Plattform** | Raspberry Pi 3/4/5, Debian Bookworm/Trixie (64-bit) |
| **Pi-hole** | v6.x (wird durch dieses Script installiert) |
| **Unbound** | Wird installiert und auf Port 5335 konfiguriert |
| **Python** | 3.12+ (für optionale Suite API) |
| **Nutzer** | Normaler Nutzer mit sudo |

Abhängigkeiten manuell installieren (optional):
```bash
sudo apt-get update
sudo apt-get install -y git curl jq dnsutils iproute2 openssl python3 python3-venv
```

---

## 🔴 Kritisch: Pi-hole muss Unbound als Upstream verwenden

> Ohne diese Einstellung ist das Setup funktional kaputt — DNSSEC wird umgangen und es wird ein externer Resolver genutzt.

Pi-hole muss DNS-Anfragen an Unbound auf **127.0.0.1#5335** weiterleiten.

**Prüfen via Pi-hole Admin → Settings → DNS:**

![Pi-hole upstream DNS setting](docs/assets/pihole-upstream-dns.png)

**Oder via Installer / Rescue Menu:**
```bash
sudo pihole-rescue   # Option 9: Pi-hole → Unbound Standardfix
```

---

## 🖥️ Management-Tools

Dieses Repo enthält drei komplementäre Verwaltungsinterfaces:

### 1. Console Menu (`scripts/console_menu.sh`)

Allgemeines interaktives Menü für die tägliche Verwaltung.

```bash
bash ~/pi-hole-unbound-v6/scripts/console_menu.sh
# oder im Text-Modus (kein dialog):
bash ~/pi-hole-unbound-v6/scripts/console_menu.sh --text
```

![Console Menu](docs/assets/screenshot_console_menu.png)

| Option | Aktion |
|--------|--------|
| 1 | Post-Install Check (Schnell) |
| 2 | Post-Install Check (Vollständig) — sudo |
| 3 | Service-URLs anzeigen |
| 4 | Manuelle Schritte-Anleitung |
| 5 | Maintenance Pro — sudo |
| 6 | Logs anzeigen |
| **7** | **Rescue & Backup Menu** |
| 8 | Beenden |

---

### 2. Rescue & Backup Menu (`scripts/rescue_menu.sh`)

Eigenständiges Wiederherstellungs- und Diagnosetool. Global aufrufbar:

```bash
sudo pihole-rescue
```

![Rescue Menu](docs/assets/screenshot_rescue_menu.png)

| Option | Aktion |
|--------|--------|
| 1 | Systemstatus (Services, DNS, Ports, Temperatur) |
| 2 | DNS-Loop / Upstream-Check |
| 3 | Nightly / Diagnosetest |
| 4 | Backup erstellen (pihole.toml + Unbound + systemd) |
| 5 | Backup wiederherstellen |
| 6 | Alte Backups löschen |
| **7** | **Last-Known-Good wiederherstellen** |
| **8** | **Emergency DNS Bypass** (Pi → 8.8.8.8/1.1.1.1, reversibel) |
| **9** | **Pi-hole → Unbound Standardfix** |
| 10 | Router / Client DNS-Hinweis (FritzBox-Anleitung) |
| 11 | Letzten Report / Log anzeigen |
| 0 | Beenden |

**Systemstatus:**

![System Status](docs/assets/screenshot_status_check.png)

**DNS-Check:**

![DNS Check](docs/assets/screenshot_dns_check.png)

---

### 3. Maintenance Pro (`tools/pihole_maintenance_pro.sh`)

Batch-Wartungsscript (apt-Updates, Pi-hole-Update, Gravity-Update, Sicherheits-Scan).

```bash
sudo bash tools/pihole_maintenance_pro.sh
# mit Flags:
sudo bash tools/pihole_maintenance_pro.sh --no-apt --no-upgrade
```

Flags: `--no-apt`, `--no-upgrade`, `--no-gravity`, `--restart-ftl`, `--backup`, `--json`

---

### 4. Automatisches Wöchentliches Update (`scripts/auto_update.sh`)

Ein gehärteter unbeaufsichtigter Update-Wrapper, der `pihole_maintenance_pro.sh` nach Zeitplan ausführt (Standard: **Sonntag 3:00 Uhr**).

**Funktionen:**
- 45-Minuten-Ausführungstimeout
- Vorab-Prüfungen: Speicherplatz, NTP-Synchronisation, apt-Lock-Erkennung
- Konfigurations-Snapshots vor dem Update (`/var/backups/pihole-auto`)
- Unbound-Konfigurationsvalidierung mit automatischem Rollback bei Fehler
- DNS-Gesundheitsprüfungen (3 Versuche auf Port 53 und 5335)
- Erkennung von Pi-hole-Hauptversionsänderungen
- Duale Reboot-Signale: `/var/run/reboot-required`-Datei + Kernel-Mismatch-Erkennung
- Reboot wird blockiert wenn DNS defekt ist (Sicherheitsschutz)
- Optionale Webhook-Benachrichtigungen via `NOTIFY_URL`-Umgebungsvariable
- Trockenlauf-Modus: `DRY_RUN=1 bash scripts/auto_update.sh`

**Auto-Update-System aktivieren:**
```bash
# Option A: Über den Installer
sudo ./install.sh --with-auto-update

# Option B: Manuelle Einrichtung
# 1. Wöchentlicher Auto-Update-Cron (Sonntag 3:00 Uhr)
(sudo crontab -l 2>/dev/null; echo '0 3 * * 0 /home/pi/pi-hole-unbound-v6/scripts/auto_update.sh') | sudo crontab -

# 2. Monatliche Unbound Root-Hints-Aktualisierung
(sudo crontab -l 2>/dev/null; echo '0 4 1 * * curl -sf -o /var/lib/unbound/root.hints.new https://www.internic.net/domain/named.root && mv /var/lib/unbound/root.hints.new /var/lib/unbound/root.hints && systemctl restart unbound') | sudo crontab -

# 3. Logrotate
sudo cp config/logrotate-pihole-auto-update /etc/logrotate.d/pihole-auto-update

# 4. Boot-Gesundheitsprüfung
sudo cp config/pihole-boot-check.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable pihole-boot-check.service

# 5. Erforderliche Verzeichnisse
sudo mkdir -p /var/backups/pihole-auto /var/log/pihole-suite
```

**Webhook-Benachrichtigungen:**
`NOTIFY_URL` setzen um Benachrichtigungen bei Update-Erfolg/-Fehler zu erhalten:
```bash
export NOTIFY_URL="https://hooks.slack.com/services/..."
```

**Boot-Gesundheitsprüfung** (`config/pihole-boot-check.service`):
Eine systemd-Oneshot-Unit, die `scripts/boot_health_check.sh` nach jedem Neustart ausführt. Sie validiert Pi-hole- und Unbound-DNS, startet Dienste bei DNS-Ausfall automatisch neu und schreibt den Status nach `/var/tmp/pihole_boot_status`.

---

## 📁 Repository-Struktur

```
pi-hole-unbound-v6/
├── install.sh                     # Haupt-Installer
├── start_suite.py                 # Optionale REST-API (FastAPI/uvicorn)
├── requirements.txt               # Python-Abhängigkeiten
├── .env.example                   # Umgebungsvariablen-Vorlage
├── config/
│   ├── logrotate-pihole-auto-update   # Logrotate für Auto-Update-Logs
│   └── pihole-boot-check.service      # Systemd-Oneshot: DNS-Prüfung nach Boot
├── scripts/
│   ├── auto_update.sh             # Gehärteter wöchentlicher Auto-Update-Wrapper
│   ├── boot_health_check.sh       # DNS-Validierung nach Neustart
│   ├── console_menu.sh            # Interaktives Verwaltungsmenü
│   ├── rescue_menu.sh             # Rescue & Backup Menü (sudo pihole-rescue)
│   ├── post_install_check.sh      # Post-Install-Verifikation
│   ├── nightly_test.sh            # Nächtlicher DNS/Service-Test
│   ├── repo_selftest.sh           # Repo-Integritäts-Selbsttest
│   └── lib/
│       └── ui.sh                  # Gemeinsame UI-Bibliothek
├── tools/
│   └── pihole_maintenance_pro.sh  # Batch-Wartungsscript
└── docs/
    ├── CONSOLE_MENU.md            # Vollständige Menü-Dokumentation
    └── assets/                    # Screenshots
```

---

## ⚙️ Post-Install Verifikation

```bash
# Schnellcheck (kein sudo)
bash scripts/post_install_check.sh --quick

# Vollständiger Check (sudo)
sudo bash scripts/post_install_check.sh --full
```

![Post-Install Check](docs/assets/screenshot_post_install.png)

---

## 🆘 Rescue-Operationen

### Emergency DNS Bypass
Wenn Pi-hole oder Unbound kaputt ist und kein DNS funktioniert:

```bash
sudo pihole-rescue   # Option 8: Emergency DNS bypass
```

Setzt den Pi direkt auf 8.8.8.8/1.1.1.1. **Vollständig reversibel** — die vorherige Konfiguration wird gespeichert und kann wiederhergestellt werden.

### Last-Known-Good Wiederherstellen
Stellt das letzte bekannt-funktionierende Backup wieder her und prüft DNS:

```bash
sudo pihole-rescue   # Option 7: Last-Known-Good
```

### Backup / Restore
```bash
sudo pihole-rescue   # Option 4: Backup erstellen
sudo pihole-rescue   # Option 5: Backup wiederherstellen
```

Backups werden in `/home/pi/pihole-rescue-backups/` gespeichert und enthalten:
- `/etc/pihole/pihole.toml`
- `/etc/unbound/unbound.conf.d/`
- Systemd Drop-in Dateien

---

## 🐍 Optional: Suite REST API

`start_suite.py` ist eine **optionale** FastAPI-Anwendung für Monitoring.

Konfiguration via `.env.example`:
```bash
# Konfiguration
cp .env.example .env
nano .env   # SUITE_API_KEY setzen

# Abhängigkeiten
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Starten
python3 start_suite.py
# API-Doku: http://127.0.0.1:8090/docs
```

**Nicht erforderlich** für den Kern-Stack (Pi-hole + Unbound).

---

## 🌐 Optional: NetAlertX

Netzwerk-Gerätemonitoring (separate Installation):

```bash
sudo ./install.sh --with-netalertx
```

---

## 🔧 Fehlerbehebung

### DNS funktioniert nicht
```bash
sudo pihole-rescue   # Option 2: DNS-Check, oder Option 8: Bypass
```

### Pi-hole nutzt nicht Unbound
```bash
sudo pihole-rescue   # Option 9: Pi-hole → Unbound Fix
```

### Systemstatus prüfen
```bash
systemctl status pihole-FTL unbound
dig +short @127.0.0.1 google.com
dig +short @127.0.0.1 -p 5335 google.com
```

### Vollständige Diagnose
```bash
sudo bash scripts/post_install_check.sh --full
sudo bash scripts/nightly_test.sh
```

### Alles ist kaputt
Wenn DNS komplett ausgefallen ist und nichts mehr funktioniert:
```bash
sudo pihole-rescue   # Option 8: Emergency DNS Bypass (sofortiger Internetzugang)
sudo pihole-rescue   # Option 7: Last-Known-Good (Backup wiederherstellen + prüfen)
```

Komplette Neuinstallation:
```bash
sudo ./install.sh --force
```

---

## 🛡️ Sicherheitshinweise

- Die Suite API bindet standardmäßig nur an **127.0.0.1**
- Immer einen starken `SUITE_API_KEY` setzen
- Pi-hole Admin-Interface ist durch Pi-holes eigene Authentifizierung geschützt
- Unbound läuft auf Port 5335 (nicht extern erreichbar ohne explizite Konfiguration)
- Sicherheitslücken melden: [SECURITY.md](SECURITY.md)

---

## 📜 Lizenz

[MIT License](LICENSE) — © TimInTech
