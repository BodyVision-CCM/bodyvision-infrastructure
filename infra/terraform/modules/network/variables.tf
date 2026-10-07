variable "project_id" {
  description = "Identifiant du projet Google Cloud"
  type        = string
}

variable "region" {
  description = "Région Google Cloud du sous-réseau"
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

variable "network_name" {
  description = "Nom du réseau VPC"
  type        = string
}

variable "subnetwork_name" {
  description = "Nom du sous-réseau principal"
  type        = string
}

variable "subnetwork_cidr" {
  description = "Plage IPv4 principale du sous-réseau"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.subnetwork_cidr))
    error_message = "La plage principale doit être un CIDR IPv4 valide."
  }
}

variable "pods_secondary_range_name" {
  description = "Nom de la plage secondaire réservée aux pods GKE"
  type        = string
}

variable "pods_secondary_cidr" {
  description = "Plage IPv4 secondaire réservée aux pods GKE"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.pods_secondary_cidr))
    error_message = "La plage des pods doit être un CIDR IPv4 valide."
  }
}

variable "services_secondary_range_name" {
  description = "Nom de la plage secondaire réservée aux services GKE"
  type        = string
}

variable "services_secondary_cidr" {
  description = "Plage IPv4 secondaire réservée aux services GKE"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.services_secondary_cidr))
    error_message = "La plage des services doit être un CIDR IPv4 valide."
  }
}