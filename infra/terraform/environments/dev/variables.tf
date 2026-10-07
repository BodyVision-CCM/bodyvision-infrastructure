variable "project_id" {
  description = "Identifiant du projet Google Cloud BodyVision"
  type        = string
}

variable "region" {
  description = "Région Google Cloud principale"
  type        = string
  default     = "europe-west9"
}

variable "environment" {
  description = "Nom de l'environnement"
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "Ce module racine est réservé à l'environnement dev."
  }
}

variable "subnetwork_cidr" {
  description = "Plage IPv4 principale du sous-réseau"
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_secondary_cidr" {
  description = "Plage IPv4 secondaire des pods GKE"
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_secondary_cidr" {
  description = "Plage IPv4 secondaire des services GKE"
  type        = string
  default     = "10.30.0.0/20"
}

variable "master_ipv4_cidr_block" {
  description = "Plage IPv4 privée du control plane GKE"
  type        = string
  default     = "172.16.0.0/28"
}

variable "node_locations" {
  description = "Zones des nœuds GKE"
  type        = list(string)
  default = [
    "europe-west9-a",
    "europe-west9-b",
    "europe-west9-c",
  ]
}

variable "gke_machine_type" {
  description = "Type de machine des nœuds GKE"
  type        = string
  default     = "e2-standard-2"
}

variable "gke_min_node_count" {
  description = "Nombre minimal de nœuds GKE"
  type        = number
  default     = 1
}

variable "gke_max_node_count" {
  description = "Nombre maximal de nœuds GKE"
  type        = number
  default     = 3
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
