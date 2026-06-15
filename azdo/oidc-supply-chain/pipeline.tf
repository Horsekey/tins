terraform {
  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~> 1.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azuredevops" {
  org_service_url = "https://dev.azure.com/${var.organization}"
}

# Both providers use az login context — no extra credentials needed
provider "azuread" {}
provider "azurerm" {
  features {}
}

variable "organization" {
  description = "Azure DevOps Organization name"
  type        = string
}

variable "project_name" {
  description = "Azure DevOps Project name"
  type        = string
}

variable "repository_name" {
  description = "Git Repository name"
  type        = string
}

variable "discord_webhook_url" {
  description = "Discord webhook URL baked into preinstall.sh at apply time"
  type        = string
  sensitive   = true
}


# Pull subscription and tenant from the current az login context
data "azurerm_subscription" "current" {}

data "azuredevops_project" "project" {
  name = var.project_name
}

# App Registration for the pipeline service connection
resource "azuread_application" "pipeline" {
  display_name = "${var.repository_name}-pipeline"
}

resource "azuread_service_principal" "pipeline" {
  client_id = azuread_application.pipeline.client_id
}

resource "azurerm_role_assignment" "pipeline_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.pipeline.object_id
}

resource "azuredevops_git_repository" "repo" {
  project_id     = data.azuredevops_project.project.id
  name           = var.repository_name
  default_branch = "refs/heads/main"
  initialization {
    init_type = "Clean"
  }
}

resource "azuredevops_serviceendpoint_azurerm" "oidc_pipeline" {
  project_id            = data.azuredevops_project.project.id
  service_endpoint_name = "oidc-pipeline"

  environment               = "AzureCloud"
  azurerm_spn_tenantid      = data.azurerm_subscription.current.tenant_id
  azurerm_subscription_id   = data.azurerm_subscription.current.subscription_id
  azurerm_subscription_name = data.azurerm_subscription.current.display_name

  depends_on = [azurerm_role_assignment.pipeline_reader]
}

# Files are committed serially to avoid branch conflicts — each depends on the previous.
resource "azuredevops_git_repository_file" "pipeline_yaml" {
  repository_id  = azuredevops_git_repository.repo.id
  file           = "supply-chain-insecure.yml"
  content        = file("${path.module}/supply-chain-insecure.yml")
  branch         = "refs/heads/main"
  commit_message = "Add supply chain insecure pipeline YAML"
}

resource "azuredevops_git_repository_file" "npmrc" {
  repository_id = azuredevops_git_repository.repo.id
  file          = ".npmrc"
  content = templatefile("${path.module}/.npmrc", {
    org     = var.organization
    project = var.project_name
    feed    = "npm-upstream"
  })
  branch         = "refs/heads/main"
  commit_message = "Add .npmrc pointing to Azure Artifacts npm-upstream feed"

  depends_on = [azuredevops_git_repository_file.pipeline_yaml]
}

resource "azuredevops_git_repository_file" "package_json" {
  repository_id  = azuredevops_git_repository.repo.id
  file           = "package.json"
  content        = file("${path.module}/package.json")
  branch         = "refs/heads/main"
  commit_message = "Add package.json"

  depends_on = [azuredevops_git_repository_file.npmrc]
}

resource "azuredevops_git_repository_file" "preinstall_sh" {
  repository_id = azuredevops_git_repository.repo.id
  file          = "preinstall.sh"
  content = replace(file("${path.module}/preinstall.sh"), "__DISCORD_WEBHOOK__", var.discord_webhook_url)
  branch         = "refs/heads/main"
  commit_message = "Add preinstall.sh"

  depends_on = [azuredevops_git_repository_file.package_json]
}

resource "azuredevops_build_definition" "manual_pipeline" {
  project_id      = data.azuredevops_project.project.id
  name            = "Electric Can Opener"
  agent_pool_name = "Azure Pipelines"

  repository {
    repo_type           = "TfsGit"
    repo_id             = azuredevops_git_repository.repo.id
    branch_name         = "main"
    yml_path            = "supply-chain-insecure.yml"
    report_build_status = true
  }

  ci_trigger {
    use_yaml = false
  }


  depends_on = [azuredevops_git_repository_file.preinstall_sh]
}

resource "azuredevops_resource_authorization" "oidc_pipeline" {
  project_id    = data.azuredevops_project.project.id
  resource_id   = azuredevops_serviceendpoint_azurerm.oidc_pipeline.id
  definition_id = azuredevops_build_definition.manual_pipeline.id
  authorized    = true
  type          = "endpoint"
}


output "pipeline_name" {
  value = azuredevops_build_definition.manual_pipeline.name
}

output "service_principal_client_id" {
  value = azuread_application.pipeline.client_id
}

output "service_connection_id" {
  value = azuredevops_serviceendpoint_azurerm.oidc_pipeline.id
}
