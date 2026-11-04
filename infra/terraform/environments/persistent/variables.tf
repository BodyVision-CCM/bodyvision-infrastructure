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

variable "github_actions_allowed_refs" {
  description = "Branches GitHub explicites autorisées ; ajouter puis retirer la branche de preuve SCRUM-108"
  type        = set(string)
  default     = ["refs/heads/main"]

  validation {
    condition = length(var.github_actions_allowed_refs) > 0 && alltrue([
      for ref in var.github_actions_allowed_refs : can(regex("^refs/heads/[A-Za-z0-9][A-Za-z0-9._/-]*$", ref))
    ])
    error_message = "Autoriser au moins une branche explicite refs/heads/... ; les tags, jokers et refs de PR sont interdits."
  }
}

variable "users_build_allowed_refs" {
  description = "Branches explicites de bodyvision-user-service autorisées à publier des images"
  type        = set(string)
  default     = ["refs/heads/main"]

  validation {
    condition = length(var.users_build_allowed_refs) > 0 && alltrue([
      for ref in var.users_build_allowed_refs : can(regex("^refs/heads/[A-Za-z0-9][A-Za-z0-9._/-]*$", ref))
    ])
    error_message = "Autoriser au moins une branche refs/heads/... explicite, sans tag, joker ou ref de PR."
  }
}
