variable "project_id" {
  description = "Identifiant du projet Google Cloud BodyVision"
  type        = string
}

variable "region" {
  description = "Région Google Cloud principale"
  type        = string
  default     = "europe-west1"
}