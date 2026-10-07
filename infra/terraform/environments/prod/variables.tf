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
  default     = "prod"

  validation {
    condition     = var.environment == "prod"
    error_message = "Ce module racine est réservé à l'environnement prod."
  }
}

