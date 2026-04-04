#!/usr/bin/env bash
# CIS Benchmark Remediation - UFW Firewall (Ubuntu Web Server)
# Fixes: 4.1.1, 4.2.3, 4.2.4, 4.2.7, and resolves conflicts with 4.3.x/4.4.x
#
# Profile: Production web server — deny incoming, allow outgoing,
#          permit only SSH (rate-limited), HTTP, and HTTPS.
# WARNING: Make sure you allow SSH BEFORE enabling if you are connected remotely.

set -euo pipefail

# --- Must run as root ---
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run this script as root (sudo)."
  exit 1
fi

echo "=== CIS Firewall Hardening — Web Server (ufw) ==="

# Step 1: Ensure only ufw is active — disable/mask nftables and iptables-persistent
echo "[1/7] Ensuring ufw is the single firewall utility (CIS 4.1.1)..."
systemctl stop nftables 2>/dev/null || true
systemctl mask nftables 2>/dev/null || true
apt-get purge -y iptables-persistent 2>/dev/null || true

# Step 2: Install ufw if not present
echo "[2/7] Installing ufw..."
apt-get update -qq
apt-get install -y ufw

# Step 3: Reset ufw to clean state (non-interactive)
echo "[3/7] Resetting ufw to defaults..."
ufw --force reset

# Step 4: Set default policies (CIS 4.2.7)
echo "[4/7] Setting default policies..."
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# Step 5: Configure loopback traffic (CIS 4.2.4)
echo "[5/7] Configuring loopback rules (CIS 4.2.4)..."
ufw allow in on lo
ufw allow out on lo
ufw deny in from 127.0.0.0/8
ufw deny in from ::1

# Step 6: Allow inbound services
echo "[6/7] Adding inbound allow rules..."

# SSH — rate-limited: drops connections from an IP that attempts
# 6+ connections within 30 seconds (brute-force mitigation)
ufw limit in 22/tcp comment 'SSH rate-limited'

# HTTP and HTTPS
ufw allow in 80/tcp  comment 'HTTP'
ufw allow in 443/tcp comment 'HTTPS'

# Step 7: Enable logging (CIS 4.2.8 — medium gives blocked + rate-limited events)
echo "[7/7] Enabling logging..."
ufw logging medium

# Enable ufw (CIS 4.2.3)
echo ""
echo "Enabling ufw..."
ufw --force enable
systemctl unmask ufw
systemctl enable ufw

# --- Verification ---
echo ""
echo "=== Verification ==="
ufw status verbose
echo ""
echo "=== Done ==="
echo "Firewall is active (deny incoming, allow outgoing, web-server-ready)."
echo ""
echo "Allowed inbound: SSH (rate-limited), HTTP (80), HTTPS (443)"
echo ""
echo "To expose an additional inbound port:"
echo "  sudo ufw allow in <port>/tcp"
