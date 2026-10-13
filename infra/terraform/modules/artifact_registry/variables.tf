variable "project_id" {
  description = "Identifiant du projet Google Cloud"
  type        = string
}

variable "region" {
  description = "Région du dépôt Docker"
  type        = string
}

variable "environment" {
  description = "Environnement du dépôt"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "L'environnement doit être dev ou prod."
  }
}

variable "repository_id" {
  description = "Identifiant du dépôt Artifact Registry"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,61}[a-z0-9]$", var.repository_id))
    error_message = "L'identifiant doit contenir 2 à 63 caractères minuscules, chiffres ou tirets, commencer par une lettre et finir par une lettre ou un chiffre."
  }
}

variable "reader_members" {
  description = "Identités autorisées à télécharger les images, au niveau du dépôt"
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for member in values(var.reader_members) : can(regex("^(serviceAccount|user|group):[^[:space:]]+@[^[:space:]]+$", member))])
    error_message = "Les lecteurs doivent être des identités serviceAccount, user ou group explicites ; l'accès public est interdit."
  }
}

variable "writer_members" {
  description = "Identités autorisées à pousser les images, au niveau du dépôt"
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for member in values(var.writer_members) : can(regex("^(serviceAccount|user|group):[^[:space:]]+@[^[:space:]]+$", member))])
    error_message = "Les auteurs doivent être des identités serviceAccount, user ou group explicites ; l'accès public est interdit."
  }
}

