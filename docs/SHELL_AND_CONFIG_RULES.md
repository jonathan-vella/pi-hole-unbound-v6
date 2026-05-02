# Shell And Config Write Rules

Use these rules for installer and maintenance changes:

- Treat a git checkout as an untrusted runtime path for root automation. Cron and systemd should run root-owned copies under `/usr/local/lib/pihole-suite`.
- Keep persistent config in `/etc/pihole-suite/pihole-suite.env`; unattended jobs must source it explicitly.
- Keep mutable state under `/var/lib/pihole-suite`, logs under `/var/log/pihole-suite`, and backups under `/var/backups/pihole-suite`.
- `--dry-run` and `DRY_RUN=1` paths must not write state, create backups, edit config, alter cron/systemd, restart services, send notifications, or reboot.
- Write config through temporary files plus validation where possible. Do not delete the live config before a replacement has been staged.
- Backups used for root restore must be root-owned, non-world-writable, and rejected if they contain symlinks.
- Do not print secrets such as `SUITE_API_KEY` or webhook URLs in normal output.
- Prefer arrays and quoted variables for shell commands. Avoid eval and avoid building shell snippets from untrusted input.
- For systemd units, generate a complete file or use an escaped path-aware mechanism; do not rewrite `ExecStart` with raw unescaped `sed` replacement.
