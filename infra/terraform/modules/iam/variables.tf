variable "project_id" {
  description = "Identifiant du projet Google Cloud"
  type        = string
}

variable "gke_nodes_service_account_email" {
  description = "Compte des nœuds géré exclusivement par persistent"
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
