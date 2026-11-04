data "google_project" "this" {
  project_id = var.project_id
}

locals {
  # Stable IDs: BodyVision-CCM / bodyvision-infrastructure, not reusable names.
  github_owner_id      = "327074116"
  github_repository_id = "1362922361"
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "bodyvision-${var.environment}-github"
  display_name              = "BodyVision ${var.environment} GitHub"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"

  attribute_mapping = {
    "google.subject"                = "assertion.sub"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.ref"                 = "assertion.ref"
  }

  attribute_condition = join(" && ", [
    "assertion.repository_owner_id == '${local.github_owner_id}'",
    "assertion.repository_id == '${local.github_repository_id}'",
    "assertion.ref in ${jsonencode(sort(tolist(var.github_actions_allowed_refs)))}",
    "assertion.event_name in ['push', 'workflow_dispatch']",
  ])

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "github_deploy" {
  project      = var.project_id
  account_id   = "bv-${var.environment}-github-deploy"
  display_name = "BodyVision ${var.environment} GitHub deployment"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_account_iam_member" "github_deploy" {
  service_account_id = google_service_account.github_deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/attribute.repository_id/${local.github_repository_id}"
}

# SCRUM-108 proves connectivity and node reads; workload writes belong to SCRUM-48.
resource "google_project_iam_custom_role" "github_gke_reader" {
  project     = var.project_id
  role_id     = "bodyvision_${var.environment}_github_gke_reader"
  title       = "BodyVision ${var.environment} GitHub GKE reader"
  description = "Connect to the DNS endpoint and list nodes, without workload or IAM writes."
  permissions = [
    "container.clusters.get",
    "container.clusters.connect",
    "container.nodes.get",
    "container.nodes.list",
  ]
}

resource "google_project_iam_member" "github_gke_reader" {
  project = var.project_id
  role    = google_project_iam_custom_role.github_gke_reader.name
  member  = "serviceAccount:${google_service_account.github_deploy.email}"
}
