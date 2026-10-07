locals {
  gke_nodes_roles = toset([
    "roles/artifactregistry.reader",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
  ])

  observability_roles = toset([
    "roles/cloudtrace.agent",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])
}

resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "bv-${var.environment}-gke-nodes"
  display_name = "BodyVision ${var.environment} GKE nodes"
  description  = "Compte de service utilisé par les nœuds du cluster GKE"
}

resource "google_service_account" "observability" {
  project      = var.project_id
  account_id   = "bv-${var.environment}-observability"
  display_name = "BodyVision ${var.environment} observability"
  description  = "Compte de service utilisé par le workload d'observabilité"
}

resource "google_project_iam_member" "gke_nodes" {
  for_each = local.gke_nodes_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "observability" {
  for_each = local.observability_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.observability.email}"
}