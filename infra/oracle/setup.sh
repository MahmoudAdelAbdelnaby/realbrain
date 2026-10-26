#!/bin/sh
# One-time setup of the Oracle A1 VM (Ubuntu 24.04 ARM), run on the VM as root from the code folder
# that deploy.sh copied over:  sudo sh /srv/reelbrain/src/infra/oracle/setup.sh
# Before: /etc/reelbrain/env (from reelbrain.env.example) and /etc/reelbrain/sa.json, both chmod 600.
set -eu
cd "$(dirname "$0")/../.."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y iptables-persistent
# Oracle's Ubuntu image rejects everything but SSH in iptables; the security list alone isn't enough.
# Saved before Docker starts so its own rules don't end up in the saved file.
for port in 80 443; do
  iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -p tcp --dport "$port" -j ACCEPT
done
netfilter-persistent save
apt-get install -y docker.io caddy unattended-upgrades
systemctl enable --now docker
mkdir -p /srv/reelbrain/data
cp infra/oracle/Caddyfile /etc/caddy/Caddyfile
systemctl reload caddy
sh infra/oracle/update.sh
