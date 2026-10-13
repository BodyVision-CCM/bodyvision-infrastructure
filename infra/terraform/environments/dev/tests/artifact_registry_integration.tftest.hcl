mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      email = "gke-nodes@bodyvision-test.iam.gserviceaccount.com"
      name  = "projects/bodyvision-test/serviceAccounts/gke-nodes@bodyvision-test.iam.gserviceaccount.com"
    }
  }
}

variables {
  project_id = "bodyvision-test"
  master_authorized_networks = [{
    cidr_block   = "203.0.113.10/32"
    display_name = "test"
  }]
}

run "dev_gke_repository_access" {
  command = apply

  assert {
    condition     = output.docker_repository_url == "europe-west9-docker.pkg.dev/bodyvision-test/bodyvision-dev-docker"
    error_message = "L'environnement dev doit exposer le préfixe Docker attendu."
  }

  assert {
    condition     = module.artifact_registry.reader_members["gke_nodes"] == "serviceAccount:${module.iam.gke_nodes_service_account_email}"
    error_message = "Les nœuds GKE doivent pouvoir lire le dépôt."
  }

  assert {
    condition     = length(module.artifact_registry.writer_members) == 0 && length(module.artifact_registry.reader_members) == 1
    error_message = "Dev doit accorder la lecture aux nœuds uniquement et aucun droit de push par défaut."
  }
}
