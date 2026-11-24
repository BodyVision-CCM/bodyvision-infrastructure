locals {
  sql_workloads = toset(["users", "analytics-api", "analytics-worker"])
}

resource "google_service_account" "cloud_sql" {
  for_each     = local.sql_workloads
  project      = var.project_id
  account_id   = "bv-${var.environment}-${each.key}-sql"
  display_name = "BodyVision ${each.key} Cloud SQL client"
}

resource "google_project_iam_member" "cloud_sql_client" {
  for_each = local.sql_workloads
  project  = var.project_id
  role     = "roles/cloudsql.client"
  member   = "serviceAccount:${google_service_account.cloud_sql[each.key].email}"
  condition {
    title       = "bodyvision-postgres-only"
    description = "Connexion uniquement à l'instance persistante BodyVision"
    expression  = "resource.name == 'projects/${var.project_id}/instances/bodyvision-${var.environment}-postgres'"
  }
}

resource "google_service_account_iam_member" "cloud_sql_workload_identity" {
  for_each           = local.sql_workloads
  service_account_id = google_service_account.cloud_sql[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${module.gke.workload_identity_pool}[bodyvision/${each.key}]"
}

output "cloud_sql_workload_service_accounts" {
  description = "Annoter chaque KSA homonyme avec iam.gke.io/gcp-service-account avant usage du proxy privé"
  value       = { for workload, account in google_service_account.cloud_sql : workload => account.email }
}
