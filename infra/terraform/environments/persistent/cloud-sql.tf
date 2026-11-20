module "network" {
  source                        = "../../modules/network"
  project_id                    = var.project_id
  region                        = var.region
  environment                   = var.environment
  network_name                  = "bodyvision-${var.environment}-vpc"
  subnetwork_name               = "bodyvision-${var.environment}-subnet"
  subnetwork_cidr               = var.subnetwork_cidr
  master_ipv4_cidr_block        = var.master_ipv4_cidr_block
  node_service_account_email    = module.iam.gke_nodes_service_account_email
  pods_secondary_range_name     = "bodyvision-${var.environment}-pods"
  pods_secondary_cidr           = var.pods_secondary_cidr
  services_secondary_range_name = "bodyvision-${var.environment}-services"
  services_secondary_cidr       = var.services_secondary_cidr
}

module "cloud_sql" {
  source            = "../../modules/cloud_sql"
  project_id        = var.project_id
  environment       = var.environment
  region            = var.region
  network_id        = module.network.network_id
  activation_policy = var.cloud_sql_activation_policy
}

variable "cloud_sql_activation_policy" {
  description = "ALWAYS pendant une session ; NEVER conserve les données en arrêtant le calcul hors session"
  type        = string
  default     = "NEVER"
  validation {
    condition     = contains(["ALWAYS", "NEVER"], var.cloud_sql_activation_policy)
    error_message = "La politique doit être ALWAYS ou NEVER."
  }
}

variable "subnetwork_cidr" {
  description = "CIDR principal du sous-réseau durable"
  type        = string
  default     = "10.10.0.0/20"
}
variable "pods_secondary_cidr" {
  description = "CIDR secondaire des pods"
  type        = string
  default     = "10.20.0.0/16"
}
variable "services_secondary_cidr" {
  description = "CIDR secondaire des Services"
  type        = string
  default     = "10.30.0.0/20"
}
variable "master_ipv4_cidr_block" {
  description = "CIDR control plane à conserver identique dans dev"
  type        = string
  default     = "172.16.0.0/28"
}

output "network_id" {
  description = "VPC durable"
  value       = module.network.network_id
}
output "network_name" {
  description = "Nom VPC durable"
  value       = module.network.network_name
}
output "subnetwork_id" {
  description = "Sous-réseau durable"
  value       = module.network.subnetwork_id
}
output "subnetwork_name" {
  description = "Nom du sous-réseau durable"
  value       = module.network.subnetwork_name
}
output "pods_secondary_range_name" {
  description = "Plage des pods"
  value       = module.network.pods_secondary_range_name
}
output "services_secondary_range_name" {
  description = "Plage des Services"
  value       = module.network.services_secondary_range_name
}
output "nat_name" {
  description = "Nom NAT durable"
  value       = module.network.nat_name
}
output "cloud_sql_connection_name" {
  description = "Connexion privée PostgreSQL"
  value       = module.cloud_sql.connection_name
}
output "cloud_sql_private_ip_address" {
  description = "IP privée pour Network Policies"
  value       = module.cloud_sql.private_ip_address
}
output "cloud_sql_database_name" {
  description = "Base PostgreSQL"
  value       = module.cloud_sql.database_name
}
