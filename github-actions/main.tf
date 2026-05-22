terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

resource "github_repository" "demo" {
  name        = var.repo_name
  description = "Edu demo of insecure GitHub Actions patterns from the GitHub Security Lab blog series. Each insecure workflow is paired with a secure counterpart."
  visibility  = "public"
  has_issues  = true  # required for IssueOps (workflow 05) demo
  auto_init   = true
}

# ── Companion action repository (supply chain demo) ──────────────────────────

resource "github_repository" "action_repo" {
  name        = var.action_repo_name
  description = "Companion demo action for the supply chain attack simulation in ${var.repo_name}. See README for attack instructions."
  visibility  = "public"
  auto_init   = true
}

resource "github_repository_file" "action_yml" {
  repository          = github_repository.action_repo.name
  branch              = "main"
  file                = "action.yml"
  content             = file("${path.module}/action-repo/action.yml")
  commit_message      = "Add benign action (v1.0)"
  overwrite_on_create = true

  depends_on = [github_repository.action_repo]
}

resource "github_repository_file" "action_readme" {
  repository          = github_repository.action_repo.name
  branch              = "main"
  file                = "README.md"
  content             = file("${path.module}/action-repo/README.md")
  commit_message      = "Add README"
  overwrite_on_create = true

  depends_on = [github_repository.action_repo]
}

# ── Demo repo workflows ───────────────────────────────────────────────────────

locals {
  workflows = [
    "01-pwn-request-insecure",
    "01-pwn-request-secure",
    "02-script-injection-insecure",
    "02-script-injection-secure",
    "04-workflow-run-insecure",
    "04-workflow-run-secure",
    "05-issueops-insecure",
    "05-issueops-secure",
  ]
}

resource "github_repository_file" "workflows" {
  for_each = toset(local.workflows)

  repository          = github_repository.demo.name
  branch              = "main"
  file                = ".github/workflows/${each.key}.yml"
  content             = file("${path.module}/workflows/${each.key}.yml")
  commit_message      = "Add workflow: ${each.key}"
  overwrite_on_create = true

  depends_on = [github_repository.demo]
}

# Workflow 03 uses templatefile() so Terraform can inject the action repo
# owner/name and the benign commit SHA — making the secure workflow's pin exact.

resource "github_repository_file" "workflow_03_insecure" {
  repository = github_repository.demo.name
  branch     = "main"
  file       = ".github/workflows/03-supply-chain-insecure.yml"
  content = templatefile("${path.module}/workflows/03-supply-chain-insecure.yml.tpl", {
    owner       = var.github_owner
    action_repo = var.action_repo_name
  })
  commit_message      = "Add workflow: 03-supply-chain-insecure"
  overwrite_on_create = true

  depends_on = [github_repository.demo]
}

resource "github_repository_file" "workflow_03_secure" {
  repository = github_repository.demo.name
  branch     = "main"
  file       = ".github/workflows/03-supply-chain-secure.yml"
  content = templatefile("${path.module}/workflows/03-supply-chain-secure.yml.tpl", {
    owner       = var.github_owner
    action_repo = var.action_repo_name
    benign_sha  = github_repository_file.action_yml.commit_sha
  })
  commit_message      = "Add workflow: 03-supply-chain-secure"
  overwrite_on_create = true

  depends_on = [github_repository.demo, github_repository_file.action_yml]
}

resource "github_repository_file" "package_json" {
  repository          = github_repository.demo.name
  branch              = "main"
  file                = "package.json"
  content             = file("${path.module}/support/package.json")
  commit_message      = "Add package.json (pwn request demo)"
  overwrite_on_create = true

  depends_on = [github_repository.demo]
}

resource "github_repository_file" "deploy_sh" {
  repository          = github_repository.demo.name
  branch              = "main"
  file                = "deploy.sh"
  content             = file("${path.module}/support/deploy.sh")
  commit_message      = "Add deploy.sh (IssueOps demo)"
  overwrite_on_create = true

  depends_on = [github_repository.demo]
}

resource "github_repository_file" "readme" {
  repository          = github_repository.demo.name
  branch              = "main"
  file                = "README.md"
  content             = file("${path.module}/README.md")
  commit_message      = "Add README"
  overwrite_on_create = true

  depends_on = [github_repository.demo]
}
