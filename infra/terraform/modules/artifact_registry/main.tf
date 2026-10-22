resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = "Images Docker privées de BodyVision ${var.environment}"
  format        = "DOCKER"
  mode          = "STANDARD_REPOSITORY"

  lifecycle {
    prevent_destroy = true
  }

  docker_config {
    immutable_tags = true
  }

  labels = {
    application = "bodyvision"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "google_artifact_registry_repository_iam_member" "readers" {
  for_each = var.reader_members

  project    = google_artifact_registry_repository.docker.project
  location   = google_artifact_registry_repository.docker.location
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.reader"
  member     = each.value
}

resource "google_artifact_registry_repository_iam_member" "writers" {
  for_each = var.writer_members

  project    = google_artifact_registry_repository.docker.project
  location   = google_artifact_registry_repository.docker.location
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.writer"
  member     = each.value
}

