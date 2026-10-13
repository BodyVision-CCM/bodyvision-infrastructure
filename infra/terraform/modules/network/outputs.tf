output "network_id" {
  description = "Identifiant du réseau VPC"
  value       = google_compute_network.this.id
}

output "network_name" {
  description = "Nom du réseau VPC"
  value       = google_compute_network.this.name
}

output "subnetwork_id" {
  description = "Identifiant du sous-réseau principal"
  value       = google_compute_subnetwork.this.id
}

output "subnetwork_name" {
  description = "Nom du sous-réseau principal"
  value       = google_compute_subnetwork.this.name
}

output "pods_secondary_range_name" {
  description = "Nom de la plage secondaire des pods GKE"
  value       = var.pods_secondary_range_name
}

output "services_secondary_range_name" {
  description = "Nom de la plage secondaire des services GKE"
  value       = var.services_secondary_range_name
}

output "router_name" {
  description = "Nom du Cloud Router"
  value       = google_compute_router.this.name
}

output "nat_name" {
  description = "Nom du Cloud NAT"
  value       = google_compute_router_nat.this.name
}