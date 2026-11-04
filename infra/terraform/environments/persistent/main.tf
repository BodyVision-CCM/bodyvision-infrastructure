# Keep module addresses unchanged for the three resources migrated from dev.
module "iam" {
  source = "../../modules/persistent_iam"

  project_id  = var.project_id
  environment = var.environment
}

module "artifact_registry" {
  source = "../../modules/artifact_registry"

  project_id    = var.project_id
  region        = var.region
  environment   = var.environment
  repository_id = "bodyvision-${var.environment}-docker"

  reader_members = { gke_nodes = "serviceAccount:${module.iam.gke_nodes_service_account_email}" }
  writer_members = merge(var.artifact_registry_writer_members, {
    github_actions = "serviceAccount:${google_service_account.github_deploy.email}"
  })
}
