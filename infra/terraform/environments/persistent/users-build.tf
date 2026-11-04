resource "google_iam_workload_identity_pool_provider" "users_build" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "user-service"

  attribute_mapping = {
    "google.subject"          = "assertion.sub"
    "attribute.repository_id" = "assertion.repository_id"
  }

  # This provider cannot impersonate the Infrastructure deployment account.
  attribute_condition = join(" && ", [
    "assertion.repository_owner_id == '${local.github_owner_id}'",
    "assertion.repository_id == '1362930912'",
    "assertion.ref in ${jsonencode(sort(tolist(var.users_build_allowed_refs)))}",
    "assertion.event_name == 'push'",
  ])

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "users_build" {
  project      = var.project_id
  account_id   = "bv-${var.environment}-users-build"
  display_name = "BodyVision ${var.environment} User Service build"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_account_iam_member" "users_build" {
  service_account_id = google_service_account.users_build.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/attribute.repository_id/1362930912"
}
