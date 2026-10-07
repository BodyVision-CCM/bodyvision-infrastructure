output "cluster_id" {
  description = "Identifiant du cluster GKE"
  value       = google_container_cluster.this.id
}

output "cluster_name" {
  description = "Nom du cluster GKE"
  value       = google_container_cluster.this.name
}

output "cluster_location" {
  description = "Région du cluster GKE"
  value       = google_container_cluster.this.location
}

output "cluster_endpoint" {
  description = "Endpoint du control plane GKE"
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "workload_identity_pool" {
  description = "Pool Workload Identity du cluster"
  value       = google_container_cluster.this.workload_identity_config[0].workload_pool
}

output "node_pool_name" {
  description = "Nom du node pool principal"
  value       = google_container_node_pool.primary.name
}