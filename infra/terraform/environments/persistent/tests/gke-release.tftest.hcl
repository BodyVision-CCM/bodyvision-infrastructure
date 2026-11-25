mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      email = "release@bodyvision-509616.iam.gserviceaccount.com"
      name  = "projects/bodyvision-509616/serviceAccounts/release@bodyvision-509616.iam.gserviceaccount.com"
    }
  }
  mock_resource "google_project_iam_custom_role" {
    defaults = { name = "projects/bodyvision-509616/roles/release" }
  }
  mock_data "google_project" {
    defaults = { number = "669761732802" }
  }
}
variables { project_id = "bodyvision-509616" }

run "release_identity_isolated" {
  command = plan
  assert {
    condition = (
      strcontains(google_iam_workload_identity_pool_provider.gke_release.attribute_condition, "assertion.ref in [\"refs/heads/main\"]") &&
      strcontains(google_iam_workload_identity_pool_provider.gke_release.attribute_condition, "assertion.event_name in ['workflow_run', 'workflow_dispatch']") &&
      strcontains(google_iam_workload_identity_pool_provider.gke_release.attribute_condition, "/.github/workflows/deploy-users.yml@") &&
      contains(keys(google_iam_workload_identity_pool_provider.gke_release.attribute_mapping), "attribute.release_repository_id") &&
      !contains(keys(google_iam_workload_identity_pool_provider.gke_release.attribute_mapping), "attribute.repository_id") &&
      !contains(keys(google_iam_workload_identity_pool_provider.gke_release.attribute_mapping), "attribute.build_repository_id")
    )
    error_message = "La livraison doit avoir sa propre confiance, limitée au workflow et à main."
  }
  assert {
    condition     = toset(google_project_iam_custom_role.gke_release.permissions) == toset(["container.clusters.get", "container.clusters.connect"])
    error_message = "Les écritures doivent rester dans RBAC, sans rôle GKE administrateur."
  }
  assert {
    condition     = !contains(keys(module.artifact_registry.writer_members), "gke_release")
    error_message = "Le déploiement ne doit pas publier d'image."
  }
}
run "release_rejects_pull_requests" {
  command = plan
  variables { gke_release_allowed_refs = ["refs/pull/10/merge"] }
  expect_failures = [var.gke_release_allowed_refs]
}
run "release_rejects_wildcards" {
  command = plan
  variables { gke_release_allowed_refs = ["refs/heads/*"] }
  expect_failures = [var.gke_release_allowed_refs]
}
