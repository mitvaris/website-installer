# MITVARIS website installer

Installs or upgrades the MITVARIS website (mitvaris.com) on a Linux server, in one line:

```bash
curl -fsSL https://raw.githubusercontent.com/mitvaris/website-installer/main/get.sh | sudo bash
```

It asks for a registry sign-in, downloads the latest release from `ghcr.io`, checks it, unpacks
it into `/opt/mitvaris-website` and runs its installer — which installs Docker if needed, asks
for the site's settings, and starts everything. Run the same line again to upgrade.

**You need** a server running Ubuntu, Debian, RHEL, Rocky, AlmaLinux, Oracle Linux, Fedora,
CentOS or Amazon Linux (x86-64, 2 vCPU / 4 GB RAM), and a **read-only** GitHub token: Settings →
Developer settings → Personal access tokens (classic) → scope `read:packages` only. That token
can download images and nothing else.

**A specific release:** `curl -fsSL …/get.sh | sudo MITVARIS_VERSION=2026.09.25-382eba8 bash`

This repository holds only this script. It contains no secrets and no application code; the
website's source is private, and the server never receives it.
