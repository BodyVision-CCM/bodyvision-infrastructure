variable "project_id" {
  description = "Projet Google Cloud BodyVision"
  type        = string
}

variable "region" {
  description = "Région du dépôt persistant"
  type        = string
  default     = "europe-west9"
}

variable "environment" {
  description = "Environnement propriétaire des ressources persistantes"
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "Ce state persistant est réservé aux ressources dev."
  }
}

variable "artifact_registry_writer_members" {
  description = "Identités de build explicites, sans accès par défaut"
  type        = map(string)
  default     = {}
}
