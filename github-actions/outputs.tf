output "repo_url" {
  description = "URL of the main demo repository"
  value       = github_repository.demo.html_url
}

output "action_repo_url" {
  description = "URL of the companion action repository (supply chain demo)"
  value       = github_repository.action_repo.html_url
}

output "benign_action_sha" {
  description = "Commit SHA of the benign v1.0 action — used in the secure workflow pin"
  value       = github_repository_file.action_yml.commit_sha
}
