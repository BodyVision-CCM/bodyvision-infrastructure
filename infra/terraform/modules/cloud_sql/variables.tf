variable "project_id" {
  description = "Projet GCP hébergeant PostgreSQL"
  type        = string
}
variable "activation_policy" {
  description = "Politique à la création uniquement (NEVER par défaut). Ensuite, démarrer/arrêter avec gcloud sql instances patch --activation-policy."
  type        = string
  default     = "NEVER"
  validation {
    condition     = contains(["ALWAYS", "NEVER"], var.activation_policy)
    error_message = "Utiliser ALWAYS pendant une session ou NEVER hors session."
  }
}
variable "environment" {
  description = "Environnement BodyVision"
  type        = string
}
variable "region" {
  description = "Région Cloud SQL"
  type        = string
  default     = "europe-west9"
}
variable "network_id" {
  description = "Identifiant complet du VPC privé"
  type        = string
}
variable "deletion_protection" {
  description = "Protection Terraform et API contre la suppression, à désactiver explicitement avant destruction"
  type        = bool
  default     = true
}
