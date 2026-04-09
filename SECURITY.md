# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest  | ✅ Yes    |
| Older   | ❌ No     |

## Scope

This project is a local Raspberry Pi setup tool. The attack surface is limited to:
- The Raspberry Pi running Pi-hole, Unbound, and (optionally) the Python Suite API
- The `SUITE_API_KEY` protecting the REST API (see `.env.example`)
- Shell scripts that run with root privileges (installer, rescue menu, auto-update)

## Reporting

Report vulnerabilities privately to **TimInTech** via GitHub
[Security Advisories](https://github.com/jonathan-vella/pi-hole-unbound-v6/security/advisories).

Please include:
- Description of the issue
- Steps to reproduce
- Potential impact (use [CVSS 3.1](https://www.first.org/cvss/calculator/3.1) scoring if possible)
- Suggested fix (if any)

Do **not** open a public issue for security vulnerabilities.

## Disclosure Timeline

- **Acknowledgement:** Within 3 business days of report
- **Triage & Fix:** Best-effort within 30 days for critical/high severity
- **Public disclosure:** After fix is released, or 90 days from report (whichever is first)

## Dependency Scanning

This project uses version-range constraints for Python dependencies (see `requirements.txt`).
Contributors should periodically review dependencies for known CVEs.
A `requirements-dev.txt` separates development-only tools from production dependencies.

## API Key Rotation

To rotate the Suite API key:
```bash
# Generate a new key
NEW_KEY=$(openssl rand -hex 32)

# Update the env file
sudo sed -i "s/^SUITE_API_KEY=.*/SUITE_API_KEY=$NEW_KEY/" /etc/pihole-suite/pihole-suite.env

# Restart the service
sudo systemctl restart pihole-suite
```

## Security Best Practices

- The Suite API binds to **127.0.0.1 only** by default — do not expose it to untrusted networks without a reverse proxy with TLS
- Always set a strong `SUITE_API_KEY` (the installer generates a 256-bit key automatically)
- Shell scripts validate inputs where they accept external data (e.g., `NOTIFY_URL` must be `http(s)://`)
- Backup restores are checked for symlinks before applying
