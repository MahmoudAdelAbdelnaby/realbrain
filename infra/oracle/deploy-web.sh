#!/bin/sh
# Deploys the landing page (web/landing) and the Caddyfile from the last commit to the Oracle VM,
# from this PC in Git Bash:  sh infra/oracle/deploy-web.sh
# Leaves the backend container alone. Only committed files ship (git archive HEAD).
set -eu
VM="${VM:-ubuntu@141.147.135.191}"
KEY="${KEY:-$HOME/.ssh/reelbrain_oracle}"
URL="${URL:-https://realbrain-mahmoud.duckdns.org}"
cd "$(dirname "$0")/../.."
git archive HEAD web/landing infra/oracle/Caddyfile | ssh -i "$KEY" "$VM" '
  set -eu
  tmp=$(mktemp -d)
  tar -x -C "$tmp"
  sudo caddy validate --adapter caddyfile --config "$tmp/infra/oracle/Caddyfile"
  sudo rm -rf /srv/reelbrain/web.new
  sudo cp -r "$tmp/web/landing" /srv/reelbrain/web.new
  sudo rm -rf /srv/reelbrain/web.old
  if [ -d /srv/reelbrain/web ]; then sudo mv /srv/reelbrain/web /srv/reelbrain/web.old; fi
  sudo mv /srv/reelbrain/web.new /srv/reelbrain/web
  sudo cp "$tmp/infra/oracle/Caddyfile" /etc/caddy/Caddyfile
  sudo systemctl reload caddy
  rm -rf "$tmp"'
# The page answers at /, and the API still answers next to it.
curl -fsS "$URL/" | grep -q '<title>Realbrain</title>' && echo "page ok"
curl -fsS "$URL/health" && echo
