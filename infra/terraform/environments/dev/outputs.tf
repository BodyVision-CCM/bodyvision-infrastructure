output "network_name" {
  description = "Nom du VPC de développement"
  value       = module.network.network_name
}

output "subnetwork_name" {
  description = "Nom du sous-réseau de développement"
  value       = module.network.subnetwork_name
}

output "nat_name" {
  description = "Nom du Cloud NAT"
  value       = module.network.nat_name
}

output "gke_nodes_service_account_email" {
  description = "Compte de service des nœuds GKE"
  value       = module.iam.gke_nodes_service_account_email
}

output "observability_service_account_email" {
  description = "Compte de service du workload d'observabilité"
  value       = module.iam.observability_service_account_email
}

output "cluster_name" {
  description = "Nom du cluster GKE"
  value       = module.gke.cluster_name
}

output "cluster_location" {
  description = "Région du cluster GKE"
  value       = module.gke.cluster_location
}

output "workload_identity_pool" {
  description = "Pool Workload Identity"
  value       = module.gke.workload_identity_pool
}