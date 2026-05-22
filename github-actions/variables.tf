variable "github_token" {
  description = "GitHub Personal Access Token with repo and workflow scopes"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub username or organization name"
  type        = string
}

variable "repo_name" {
  description = "Name of the main demo repository to create"
  type        = string
  default     = "github-actions-vulns-demo"
}

variable "action_repo_name" {
  description = "Name of the companion action repository used for the supply chain demo"
  type        = string
  default     = "github-actions-vulns-demo-action"
}
