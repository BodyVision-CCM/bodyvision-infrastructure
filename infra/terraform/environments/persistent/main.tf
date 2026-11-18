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
    users_build    = "serviceAccount:${google_service_account.users_build.email}"
  })
}

resource "google_storage_bucket" "raw_telemetry" {
  name                        = "${var.project_id}-bodyvision-telemetry-raw"
  project                     = var.project_id
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  soft_delete_policy {
    retention_duration_seconds = 0
  }

  lifecycle_rule {
    condition {
      age = 30
    }

    action {
      type = "Delete"
    }
  }

  labels = {
    application = "bodyvision"
    managed_by  = "terraform"
    purpose     = "raw-telemetry"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_account" "telemetry_gateway" {
  project      = var.project_id
  account_id   = "bv-${var.environment}-ingestion-telemetry"
  display_name = "BodyVision ${var.environment} ingestion telemetry"
  description  = "Compte utilisé par le service Ingestion pour déposer les lots de télémétrie brute"
}

resource "google_service_account" "analytics_telemetry_reader" {
  project      = var.project_id
  account_id   = "bv-${var.environment}-analytics-telemetry"
  display_name = "BodyVision ${var.environment} analytics telemetry reader"
  description  = "Compte utilisé par le microservice Analytique pour lire la télémétrie brute"
}

resource "google_storage_bucket_iam_member" "telemetry_gateway_writer" {
  bucket = google_storage_bucket.raw_telemetry.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.telemetry_gateway.email}"
}

resource "google_storage_bucket_iam_member" "analytics_telemetry_reader" {
  bucket = google_storage_bucket.raw_telemetry.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.analytics_telemetry_reader.email}"
}
