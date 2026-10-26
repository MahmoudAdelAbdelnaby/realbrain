#!/bin/sh
# Deploys the last commit to the Oracle VM, from this PC in Git Bash:  sh infra/oracle/deploy.sh
# Only committed code ships (git archive HEAD); the repo has no remote for the VM to pull from.
set -eu
VM="${VM:-ubuntu@141.147.135.191}"
KEY="${KEY:-$HOME/.ssh/reelbrain_oracle}"
cd "$(dirname "$0")/../.."
git archive HEAD backend infra | ssh -i "$KEY" "$VM" \
  'sudo rm -rf /srv/reelbrain/src && sudo mkdir -p /srv/reelbrain/src && sudo tar -x -C /srv/reelbrain/src && sudo sh /srv/reelbrain/src/infra/oracle/update.sh'
