variable "project_id" {
  description = "Identifiant du projet Google Cloud"
  type        = string
}

variable "services" {
  description = "Liste des API Google Cloud à activer"
  type        = set(string)
}