mock_provider "google" {}

variables {
  project_id    = "bodyvision-test"
  region        = "europe-west9"
  environment   = "dev"
  repository_id = "bodyvision-dev-docker"
}

run "private_docker_repository" {
  command = plan

  module {
    source = "../../modules/artifact_registry"
  }

  assert {
    condition     = google_artifact_registry_repository.docker.format == "DOCKER" && google_artifact_registry_repository.docker.mode == "STANDARD_REPOSITORY"
    error_message = "Le dépôt doit stocker des images Docker en mode standard."
  }

  assert {
    condition     = google_artifact_registry_repository.docker.docker_config[0].immutable_tags
    error_message = "Les tags doivent être immuables."
  }

  assert {
    condition     = length(google_artifact_registry_repository_iam_member.readers) == 0 && length(google_artifact_registry_repository_iam_member.writers) == 0
    error_message = "Aucune identité ne doit recevoir un accès par défaut."
  }

  assert {
    condition     = output.docker_repository_url == "europe-west9-docker.pkg.dev/bodyvision-test/bodyvision-dev-docker"
    error_message = "Le préfixe Docker doit contenir la région, le projet et le dépôt."
  }
}

run "repository_scoped_access" {
  command = apply

  module {
    source = "../../modules/artifact_registry"
  }

  variables {
    reader_members = { gke = "serviceAccount:gke@bodyvision-test.iam.gserviceaccount.com" }
    writer_members = { build = "serviceAccount:build@bodyvision-test.iam.gserviceaccount.com" }
  }

  assert {
    condition = (
      google_artifact_registry_repository_iam_member.readers["gke"].role == "roles/artifactregistry.reader" &&
      google_artifact_registry_repository_iam_member.writers["build"].role == "roles/artifactregistry.writer" &&
      google_artifact_registry_repository_iam_member.readers["gke"].repository == google_artifact_registry_repository.docker.name &&
      google_artifact_registry_repository_iam_member.writers["build"].repository == google_artifact_registry_repository.docker.name
    )
    error_message = "Les lecteurs et auteurs doivent recevoir leur rôle au niveau du dépôt."
  }
}

run "reject_public_reader" {
  command = plan

  module {
    source = "../../modules/artifact_registry"
  }

  variables {
    reader_members = { public = "allUsers" }
  }

  expect_failures = [var.reader_members]
}

run "reject_public_writer" {
  command = plan

  module {
    source = "../../modules/artifact_registry"
  }

  variables {
    writer_members = { public = "allAuthenticatedUsers" }
  }

  expect_failures = [var.writer_members]
}

run "reject_invalid_repository_id" {
  command = plan

  module {
    source = "../../modules/artifact_registry"
  }

  variables {
    repository_id = "INVALID_repository"
  }

  expect_failures = [var.repository_id]
}
