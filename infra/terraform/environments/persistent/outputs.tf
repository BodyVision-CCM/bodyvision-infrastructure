output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

output "environment" {
  value = var.environment
}

output "gke_nodes_service_account_email" {
  value = module.iam.gke_nodes_service_account_email
}

output "artifact_registry_repository_name" {
  value = module.artifact_registry.repository_name
}

output "docker_registry_host" {
  value = module.artifact_registry.docker_registry_host
}

output "docker_repository_url" {
  value = module.artifact_registry.docker_repository_url
}

output "github_workload_identity_provider" {
  description = "Identifiant public du fournisseur OIDC GitHub"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "github_deploy_service_account_email" {
  value = google_service_account.github_deploy.email
}

output "users_build_workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.users_build.name
}

output "users_build_service_account_email" {
  value = google_service_account.users_build.email
}
