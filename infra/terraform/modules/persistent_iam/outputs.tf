output "gke_nodes_service_account_email" {
  value = google_service_account.gke_nodes.email
}
