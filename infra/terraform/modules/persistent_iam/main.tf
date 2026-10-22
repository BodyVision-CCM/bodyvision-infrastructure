resource "google_service_account" "gke_nodes" {
  project      = var.project_id
  account_id   = "bv-${var.environment}-gke-nodes"
  display_name = "BodyVision ${var.environment} GKE nodes"
  description  = "Compte de service utilisé par les nœuds du cluster GKE"

  lifecycle {
    prevent_destroy = true
  }
}
