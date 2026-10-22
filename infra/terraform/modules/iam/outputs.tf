output "gke_nodes_service_account_email" {
  description = "Adresse du compte de service utilisé par les nœuds GKE"
  value       = var.gke_nodes_service_account_email
}

output "observability_service_account_email" {
  description = "Adresse du compte de service Google utilisé par le workload d'observabilité"
  value       = google_service_account.observability.email
}

output "observability_service_account_name" {
  description = "Nom Terraform complet du compte de service d'observabilité"
  value       = google_service_account.observability.name
}
