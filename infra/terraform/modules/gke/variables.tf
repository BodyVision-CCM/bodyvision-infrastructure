variable "project_id" {
  description = "Identifiant du projet Google Cloud"
  type        = string
}

variable "region" {
  description = "Région du cluster GKE"
  type        = string
}

variable "environment" {
  description = "Nom de l'environnement"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "L'environnement doit être dev ou prod."
  }
}

variable "cluster_name" {
  description = "Nom du cluster GKE"
  type        = string
}

variable "network_id" {
  description = "Identifiant du réseau VPC utilisé par GKE"
  type        = string
}

variable "subnetwork_id" {
  description = "Identifiant du sous-réseau utilisé par GKE"
  type        = string
}

variable "pods_secondary_range_name" {
  description = "Nom de la plage secondaire des pods"
  type        = string
}

variable "services_secondary_range_name" {
  description = "Nom de la plage secondaire des services"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "Plage IPv4 privée réservée au control plane GKE"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.master_ipv4_cidr_block))
    error_message = "La plage du control plane doit être un CIDR IPv4 valide."
  }
}

variable "node_locations" {
  description = "Zones dans lesquelles les nœuds GKE sont déployés"
  type        = list(string)
}

variable "node_service_account_email" {
  description = "Adresse du compte de service utilisé par les nœuds"
  type        = string
}

variable "machine_type" {
  description = "Type de machine utilisé par le node pool"
  type        = string
  default     = "e2-standard-2"
}

variable "disk_size_gb" {
  description = "Taille du disque de chaque nœud"
  type        = number
  default     = 50

  validation {
    condition     = var.disk_size_gb >= 30
    error_message = "La taille du disque doit être au minimum de 30 Go."
  }
}

variable "min_node_count" {
  description = "Nombre minimal de nœuds"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Nombre maximal de nœuds"
  type        = number
  default     = 3

  validation {
    condition     = var.max_node_count >= var.min_node_count
    error_message = "Le maximum doit être supérieur ou égal au minimum."
  }
}
variable "master_authorized_networks" {
  description = "Réseaux autorisés à joindre l'endpoint du control plane"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))

  validation {
    condition = alltrue([
      for network in var.master_authorized_networks :
      can(cidrnetmask(network.cidr_block))
    ])
    error_message = "Chaque réseau autorisé doit utiliser un CIDR valide."
  }
}
variable "deletion_protection" {
  description = "Active la protection Terraform contre la suppression du cluster"
  type        = bool
  default     = false
}
