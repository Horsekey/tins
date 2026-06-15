# Electric Can Opener

Provision a full Azure DevOps demo environment for demonstrating supply chain attack vectors via a malicious `preinstall` script in an npm package.

## What gets created

| Resource | Description |
|---|---|
| `azuread_application` + `azuread_service_principal` | App Registration and SP for the pipeline service connection |
| `azurerm_role_assignment` | Grants the SP Reader on the current subscription (enough for `AzureCLI@2` to authenticate; intentionally minimal) |
| `azuredevops_serviceendpoint_azurerm` | Service connection named `oidc-pipeline` wired to the SP |
| `azuredevops_git_repository` | New repo seeded with all demo files |
| `azuredevops_build_definition` | Pipeline pointing at `supply-chain-insecure.yml` |
| `azuredevops_resource_authorization` | Authorizes `oidc-pipeline` for this pipeline |

## Files pushed to the repo

- `supply-chain-insecure.yml` — pipeline definition; authenticates to the Artifacts feed then runs `npm install`
- `.npmrc` — points npm at the Azure Artifacts feed (org/project/feed interpolated by Terraform)
- `package.json` — declares a `preinstall` script that executes `preinstall.sh`
- `preinstall.sh` — the malicious payload; exfiltrates env vars, `.npmrc`, Azure credentials, and MSAL token caches to Discord

## Prerequisites

1. An existing Azure DevOps **project** (Terraform looks it up by name — it does not create it).
2. `az login` completed against the target subscription (used by the `azuread` and `azurerm` providers).

## Authentication

Two auth contexts are needed:

**Azure CLI** — used by the `azuread` and `azurerm` providers to create the SP and role assignment:

```bash
az login
az account set --subscription "<your-subscription-id-or-name>"
```

**Azure DevOps PAT** — used by the `azuredevops` provider:

```bash
export AZDO_PERSONAL_ACCESS_TOKEN="<your-pat>"
export AZDO_ORG_SERVICE_URL="https://dev.azure.com/<your-org>"
```

PAT scope required: Code, Build, Packaging, Service Connections, Variable Groups — Read & Write (or Full access).

> PATs expire — if `terraform apply` starts failing with 401s, regenerate the token and re-export it.

## Setup

```bash
cp example.tfvars terraform.tfvars
# Edit terraform.tfvars
terraform init
terraform apply -var-file=terraform.tfvars
```

## Required variables

| Variable | Description |
|---|---|
| `organization` | Azure DevOps org name (the part after `dev.azure.com/`) |
| `project_name` | Existing Azure DevOps project name |
| `repository_name` | Name for the new git repository |
| `discord_webhook_url` | Discord webhook URL — baked into `preinstall.sh` at apply time |

## Discord webhook

Set `discord_webhook_url` in your `terraform.tfvars` before applying. Terraform bakes it directly into `preinstall.sh` via `templatefile()` when committing the file to the repo — the same way org/project/feed are interpolated into `.npmrc`.

To get a webhook URL: Discord server settings → Integrations → Webhooks → New Webhook → Copy Webhook URL.

## Post-apply manual step — switch service connection to WIF

Terraform creates the service connection using a client secret as a bootstrap credential, then immediately revokes it. Before the pipeline can run, switch the service connection to workload identity federation:

Project Settings → **Service connections** → `oidc-pipeline` → Edit → switch **Authentication** to **Workload identity federation** → Save.

## Demo flow

1. `terraform apply` — provisions everything including the SP and service connection
2. In Azure DevOps, run **Electric Can Opener** manually
3. The pipeline authenticates to the Artifacts feed, then calls `npm install`
4. npm triggers the `preinstall` script, which exfiltrates:
   - Agent environment variables
   - The resolved `.npmrc` (containing the system access token)
   - `azureProfile.json` (Azure CLI credentials)
   - `msal_token_cache.json` (MSAL token cache)
   - `.agent` config file
5. All data arrives in the configured Discord channel
