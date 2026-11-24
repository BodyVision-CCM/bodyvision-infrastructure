data "google_project" "this" {
  project_id = var.project_id
}

# Secret contents and versions are provisioned outside Terraform and its state.
resource "google_secret_manager_secret_iam_member" "users" {
  for_each = toset([
    "bv-${var.environment}-utilisateurs-db-password",
    "bv-${var.environment}-users-internal-token",
    "bv-${var.environment}-users-jwt-private-key",
  ])
  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "principal://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${module.gke.workload_identity_pool}/subject/ns/bodyvision/sa/users"
}
