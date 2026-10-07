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

