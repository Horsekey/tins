#!/bin/bash
# Demo deploy script — shows what runs with privileged access in the IssueOps workflows.
# In the insecure workflow (05) an attacker can replace this file between the maintainer's /deploy comment and the checkout step (TOCTOU).

echo "deploy.sh executing"
echo "Commit: $(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
echo "Runner user: $(whoami)"
echo ""
echo "Env var names visible to this script (values hidden):"
env | cut -d= -f1 | sort
echo ""
