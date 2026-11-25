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
  # The annotated KSA impersonates this GSA for both CSI and the SQL proxy.
  member = "serviceAccount:${google_service_account.cloud_sql["users"].email}"
}
