#!/bin/sh
# Builds and (re)starts the backend from the code deploy.sh copied to /srv/reelbrain/src. Run as root.
set -eu
cd "$(dirname "$0")/../.."
docker build -t reelbrain backend
docker rm -f reelbrain 2>/dev/null || true
# --restart: Docker brings it back after a crash or a reboot. --publish: phones follow this URL.
docker run -d --name reelbrain --restart unless-stopped \
  -p 127.0.0.1:8000:8000 \
  --env-file /etc/reelbrain/env \
  -v /etc/reelbrain/sa.json:/secrets/sa.json:ro \
  -v /srv/reelbrain/data:/srv/data \
  reelbrain python -m scripts.serve --lan --publish --port 8000
docker image prune -f
for _ in 1 2 3 4 5 6 7 8 9 10; do
  curl -fsS http://127.0.0.1:8000/health && echo && exit 0
  sleep 3
done
docker logs --tail 50 reelbrain
exit 1
