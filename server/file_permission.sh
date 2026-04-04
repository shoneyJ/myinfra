#!/usr/bin/env bash
# CIS Benchmark Remediation - Recommendation #7: Fix File Permissions
# Fixes: 2.4.1.2, 2.4.1.3, 2.4.1.4, 2.4.1.5, 2.4.1.6, 2.4.1.7, 7.1.10, 6.1.4.1
#
# Safe to run — only tightens permissions on system files.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run this script as root (sudo)."
  exit 1
fi

echo "=== CIS File Permissions Hardening ==="

# -------------------------------------------------------------------
# Cron permissions (CIS 2.4.1.2 - 2.4.1.7)
# -------------------------------------------------------------------
echo "[1/4] Fixing cron file/directory permissions..."

# CIS 2.4.1.2 - /etc/crontab
if [[ -f /etc/crontab ]]; then
  chown root:root /etc/crontab
  chmod 600 /etc/crontab
  echo "  /etc/crontab          → root:root 600"
fi

# CIS 2.4.1.3 - /etc/cron.hourly
if [[ -d /etc/cron.hourly ]]; then
  chown root:root /etc/cron.hourly
  chmod 700 /etc/cron.hourly
  echo "  /etc/cron.hourly/     → root:root 700"
fi

# CIS 2.4.1.4 - /etc/cron.daily
if [[ -d /etc/cron.daily ]]; then
  chown root:root /etc/cron.daily
  chmod 700 /etc/cron.daily
  echo "  /etc/cron.daily/      → root:root 700"
fi

# CIS 2.4.1.5 - /etc/cron.weekly
if [[ -d /etc/cron.weekly ]]; then
  chown root:root /etc/cron.weekly
  chmod 700 /etc/cron.weekly
  echo "  /etc/cron.weekly/     → root:root 700"
fi

# CIS 2.4.1.6 - /etc/cron.monthly
if [[ -d /etc/cron.monthly ]]; then
  chown root:root /etc/cron.monthly
  chmod 700 /etc/cron.monthly
  echo "  /etc/cron.monthly/    → root:root 700"
fi

# CIS 2.4.1.7 - /etc/cron.d
if [[ -d /etc/cron.d ]]; then
  chown root:root /etc/cron.d
  chmod 700 /etc/cron.d
  echo "  /etc/cron.d/          → root:root 700"
fi

# -------------------------------------------------------------------
# Password history file (CIS 7.1.10)
# -------------------------------------------------------------------
echo ""
echo "[2/4] Fixing /etc/security/opasswd permissions (CIS 7.1.10)..."

if [[ -f /etc/security/opasswd ]]; then
  chown root:root /etc/security/opasswd
  chmod 600 /etc/security/opasswd
  echo "  /etc/security/opasswd → root:root 600"
else
  # Create it if it doesn't exist (needed by pam_pwhistory)
  touch /etc/security/opasswd
  chown root:root /etc/security/opasswd
  chmod 600 /etc/security/opasswd
  echo "  /etc/security/opasswd → created, root:root 600"
fi

# Handle opasswd.old if it exists
if [[ -f /etc/security/opasswd.old ]]; then
  chown root:root /etc/security/opasswd.old
  chmod 600 /etc/security/opasswd.old
  echo "  /etc/security/opasswd.old → root:root 600"
fi

# -------------------------------------------------------------------
# Log file permissions (CIS 6.1.4.1)
# -------------------------------------------------------------------
echo ""
echo "[3/4] Fixing /var/log file permissions (CIS 6.1.4.1)..."

# Set all log files to be readable only by root/adm group
find /var/log -type f -exec chmod g-wx,o-rwx {} +
find /var/log -type f -exec chown root:adm {} + 2>/dev/null || true

# Some logs have specific expected ownership
[[ -f /var/log/syslog ]]    && chown syslog:adm /var/log/syslog
[[ -f /var/log/auth.log ]]  && chown syslog:adm /var/log/auth.log
[[ -f /var/log/kern.log ]]  && chown syslog:adm /var/log/kern.log

# Set log directories
find /var/log -type d -exec chmod g-w,o-rwx {} +

echo "  /var/log/**           → owner root/syslog, group adm, no world access"

# -------------------------------------------------------------------
# Verification
# -------------------------------------------------------------------
echo ""
echo "[4/4] Verifying..."
echo ""
echo "--- Cron permissions ---"
ls -l /etc/crontab 2>/dev/null
ls -ld /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.d 2>/dev/null
echo ""
echo "--- opasswd permissions ---"
ls -l /etc/security/opasswd 2>/dev/null
ls -l /etc/security/opasswd.old 2>/dev/null || true
echo ""
echo "--- /var/log sample permissions ---"
ls -l /var/log/syslog /var/log/auth.log /var/log/kern.log 2>/dev/null || true
echo ""
echo "=== Done ==="
