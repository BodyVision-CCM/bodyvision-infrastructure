variable "gke_release_allowed_refs" {
  description = "Branches explicites autorisées à déployer ; retirer la branche de preuve après validation"
  type        = set(string)
  default     = ["refs/heads/main"]
  validation {
    condition = length(var.gke_release_allowed_refs) > 0 && alltrue([
      for ref in var.gke_release_allowed_refs : can(regex("^refs/heads/[A-Za-z0-9][A-Za-z0-9._/-]*$", ref))
    ])
    error_message = "Autoriser uniquement des branches refs/heads/... explicites, sans joker ni ref de PR."
  }
}

resource "google_iam_workload_identity_pool_provider" "gke_release" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "gke-release"
  attribute_mapping = {
    "google.subject"                  = "assertion.sub"
    "attribute.release_repository_id" = "assertion.repository_id"
  }
  attribute_condition = join(" && ", [
    "assertion.repository_owner_id == '${local.github_owner_id}'",
    "assertion.repository_id == '${local.github_repository_id}'",
    "assertion.ref in ${jsonencode(sort(tolist(var.gke_release_allowed_refs)))}",
    "assertion.event_name in ['workflow_run', 'workflow_dispatch', 'push']",
    "assertion.workflow_ref.endsWith('/.github/workflows/deploy-users.yml@' + assertion.ref)",
  ])
  oidc { issuer_uri = "https://token.actions.githubusercontent.com" }
}

resource "google_service_account" "gke_release" {
  project      = var.project_id
  account_id   = "bv-${var.environment}-gke-release"
  display_name = "BodyVision ${var.environment} namespace deployment"
}

resource "google_service_account_iam_member" "gke_release" {
  service_account_id = google_service_account.gke_release.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/attribute.release_repository_id/${local.github_repository_id}"
}

# Workload writes are granted by namespace RBAC, never by a project-wide GKE role.
resource "google_project_iam_custom_role" "gke_release" {
  project     = var.project_id
  role_id     = "bodyvision_${var.environment}_gke_release"
  title       = "BodyVision ${var.environment} GKE connection"
  permissions = ["container.clusters.get", "container.clusters.connect"]
}

resource "google_project_iam_member" "gke_release" {
  project = var.project_id
  role    = google_project_iam_custom_role.gke_release.name
  member  = "serviceAccount:${google_service_account.gke_release.email}"
}

output "gke_release_workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.gke_release.name
}
output "gke_release_service_account_email" {
  value = google_service_account.gke_release.email
}
