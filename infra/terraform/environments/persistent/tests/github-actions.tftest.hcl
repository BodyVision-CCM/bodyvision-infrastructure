mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      email = "mock-ci@bodyvision-509616.iam.gserviceaccount.com"
      name  = "projects/bodyvision-509616/serviceAccounts/mock-ci@bodyvision-509616.iam.gserviceaccount.com"
    }
  }

  mock_resource "google_project_iam_custom_role" {
    defaults = {
      name = "projects/bodyvision-509616/roles/bodyvision_dev_github_gke_reader"
    }
  }

  mock_data "google_project" {
    defaults = {
      number = "669761732802"
    }
  }
}

override_resource {
  target = google_service_account.github_deploy
  values = {
    email = "bv-dev-github-deploy@bodyvision-509616.iam.gserviceaccount.com"
    name  = "projects/bodyvision-509616/serviceAccounts/bv-dev-github-deploy@bodyvision-509616.iam.gserviceaccount.com"
  }
}

override_resource {
  target = google_service_account.users_build
  values = {
    email = "bv-dev-users-build@bodyvision-509616.iam.gserviceaccount.com"
    name  = "projects/bodyvision-509616/serviceAccounts/bv-dev-users-build@bodyvision-509616.iam.gserviceaccount.com"
  }
}

variables {
  project_id                  = "bodyvision-509616"
  github_actions_allowed_refs = ["refs/heads/main"]
  users_build_allowed_refs    = ["refs/heads/main"]
}

run "users_build_isolated_identity" {
  command = apply

  assert {
    condition = google_iam_workload_identity_pool_provider.users_build.attribute_condition == join(" && ", [
      "assertion.repository_owner_id == '327074116'",
      "assertion.repository_id == '1362922361'",
      "assertion.ref in [\"refs/heads/main\"]",
      "assertion.event_name in ['push', 'workflow_dispatch']",
    ])
    error_message = "Seul un push ou lancement manuel main du dépôt Infrastructure doit être accepté."
  }

  assert {
    condition = (
      google_service_account_iam_member.users_build.member == "principalSet://iam.googleapis.com/projects/669761732802/locations/global/workloadIdentityPools/bodyvision-dev-github/attribute.build_repository_id/1362922361" &&
      google_service_account_iam_member.users_build.role == "roles/iam.workloadIdentityUser" &&
      !contains(keys(google_iam_workload_identity_pool_provider.users_build.attribute_mapping), "attribute.repository_id") &&
      !contains(keys(google_iam_workload_identity_pool_provider.github.attribute_mapping), "attribute.build_repository_id") &&
      module.artifact_registry.writer_members["users_build"] == "serviceAccount:${google_service_account.users_build.email}" &&
      google_project_iam_member.github_gke_reader.member != "serviceAccount:${google_service_account.users_build.email}"
    )
    error_message = "Le compte Utilisateurs doit publier au registre sans prendre l'identité ou les droits GKE d'Infrastructure."
  }
}

run "users_explicit_test_branch" {
  command = plan

  variables {
    users_build_allowed_refs = ["refs/heads/main", "refs/heads/codex/scrum-43-build-push"]
  }

  assert {
    condition     = strcontains(google_iam_workload_identity_pool_provider.users_build.attribute_condition, "assertion.ref in [\"refs/heads/codex/scrum-43-build-push\",\"refs/heads/main\"]")
    error_message = "La branche de preuve Utilisateurs doit être autorisée explicitement."
  }
}

run "users_reject_wildcard" {
  command = plan
  variables {
    users_build_allowed_refs = ["refs/heads/*"]
  }
  expect_failures = [var.users_build_allowed_refs]
}

run "users_reject_pull_request_ref" {
  command = plan
  variables {
    users_build_allowed_refs = ["refs/pull/1/merge"]
  }
  expect_failures = [var.users_build_allowed_refs]
}

run "main_only_and_least_privilege" {
  command = apply

  assert {
    condition = google_iam_workload_identity_pool_provider.github.attribute_condition == join(" && ", [
      "assertion.repository_owner_id == '327074116'",
      "assertion.repository_id == '1362922361'",
      "assertion.ref in [\"refs/heads/main\"]",
      "assertion.event_name in ['push', 'workflow_dispatch']",
    ])
    error_message = "La confiance doit être limitée aux IDs BodyVision, à main et aux événements sans PR."
  }

  assert {
    condition = toset(google_project_iam_custom_role.github_gke_reader.permissions) == toset([
      "container.clusters.get", "container.clusters.connect", "container.nodes.get", "container.nodes.list",
    ])
    error_message = "La preuve ne doit donner aucun droit d'écriture GKE ou IAM."
  }

  assert {
    condition = (
      google_service_account_iam_member.github_deploy.role == "roles/iam.workloadIdentityUser" &&
      google_service_account_iam_member.github_deploy.member == "principalSet://iam.googleapis.com/projects/669761732802/locations/global/workloadIdentityPools/bodyvision-dev-github/attribute.repository_id/1362922361" &&
      google_iam_workload_identity_pool_provider.github.oidc[0].issuer_uri == "https://token.actions.githubusercontent.com"
    )
    error_message = "Utiliser uniquement le fournisseur GitHub et le dépôt Infrastructure pour l'impersonation."
  }

  assert {
    condition     = module.artifact_registry.writer_members["github_actions"] == "serviceAccount:${google_service_account.github_deploy.email}"
    error_message = "Le writer doit rester attaché au registre existant."
  }
}

run "explicit_test_branch" {
  command = plan

  variables {
    github_actions_allowed_refs = ["refs/heads/main", "refs/heads/codex/scrum-108-github-gcp"]
  }

  assert {
    condition     = strcontains(google_iam_workload_identity_pool_provider.github.attribute_condition, "assertion.ref in [\"refs/heads/codex/scrum-108-github-gcp\",\"refs/heads/main\"]")
    error_message = "La branche de preuve doit être autorisée explicitement, sans joker."
  }
}

run "reject_wildcard" {
  command = plan

  variables {
    github_actions_allowed_refs = ["refs/heads/*"]
  }

  expect_failures = [var.github_actions_allowed_refs]
}

run "reject_pull_request_ref" {
  command = plan

  variables {
    github_actions_allowed_refs = ["refs/pull/1/merge"]
  }

  expect_failures = [var.github_actions_allowed_refs]
}
