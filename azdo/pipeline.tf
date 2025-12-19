terraform {
  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~> 0.10.0"
    }
  }
}

provider "azuredevops" {
  org_service_url       = "https://dev.azure.com/${var.organization}"
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
  description = "Discord webhook URL for notifications"
  type        = string
  sensitive   = true
}

data "azuredevops_project" "project" {
  name = var.project_name
}

resource "azuredevops_git_repository" "repo" {
  project_id = data.azuredevops_project.project.id
  name       = var.repository_name
  default_branch = "refs/heads/main"
  initialization {
    init_type = "Clean"
  }
}

# Create the YAML pipeline file in the repository
resource "azuredevops_git_repository_file" "pipeline_yaml" {
  repository_id = azuredevops_git_repository.repo.id
  file          = "sample-pipeline.yml"
  content       = file("${path.module}/sample-pipeline.yml")
  branch        = "refs/heads/main"
  
  commit_message = "Add sample pipeline YAML file via Terraform"
}

# Create the build pipeline that references the YAML file
resource "azuredevops_build_definition" "manual_pipeline" {
  project_id           = data.azuredevops_project.project.id
  name                 = "Manual Sample Pipeline"
  agent_pool_name      = "Azure Pipelines"

  repository {
    repo_type             = "TfsGit"
    repo_id               = azuredevops_git_repository.repo.id
    branch_name           = "main"
    yml_path              = "sample-pipeline.yml"
    report_build_status   = true
  }

  # Disable CI trigger - pipeline only runs manually
  ci_trigger {
    use_yaml = false
  }

  variable_groups = [azuredevops_variable_group.discord.id]

  depends_on = [azuredevops_git_repository_file.pipeline_yaml]

}

resource "azuredevops_variable_group" "discord" {
  project_id   = data.azuredevops_project.project.id
  name         = "Discord Webhook"
  allow_access = true

  variable {
    name         = "DISCORD_WEBHOOK_URL"
    secret_value = var.discord_webhook_url
    is_secret    = true
  }
}

output "pipeline_name" {
  value = azuredevops_build_definition.manual_pipeline.name
}

output "yaml_file_path" {
  value = azuredevops_git_repository_file.pipeline_yaml.file
}