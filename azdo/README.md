# AzDo

## Boilerplate AZDO Pipeline for Testing OIDC Endpoint

If you want to test this yourself, check out the quick terraform template

```bash
# 1. create azdo organization
https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/create-organization

# 2. deploy self-hosted agent
https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/linux-agent

# 3. clone repo
git clone https://github.com/Horsekey/tins

# 4. create PAT with these scopes
build: read,execute
code: read,write,manage
variable_groups: read,create,manage

# 5. set azdo pat in environment variables
export AZDO_PERSONAL_ACCESS_TOKEN = "your-pat-token" # bash
$env:AZDO_PERSONAL_ACCESS_TOKEN =  "your-pat-token" # powershell

# 6. configure tfvars
vi example.tfvars

# 7. build
terraform init
terraform plan
terraform apply

# 8. test oidc endpoint (oidc_url from pipeline, auth_header from discord post)
curl -X POST "$OIDC_URL" -H "Authorization: Basic $AUTH_HEADER" -H "Content-Type: application/json" -d '{}'
```