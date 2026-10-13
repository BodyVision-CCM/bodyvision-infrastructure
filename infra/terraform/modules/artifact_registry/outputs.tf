output "repository_id" {
  description = "Identifiant du dépôt Docker"
  value       = google_artifact_registry_repository.docker.repository_id
}

output "reader_members" {
  description = "Identités disposant du rôle lecteur sur le dépôt"
  value       = { for key, binding in google_artifact_registry_repository_iam_member.readers : key => binding.member }
}

output "writer_members" {
  description = "Identités disposant du rôle auteur sur le dépôt"
  value       = { for key, binding in google_artifact_registry_repository_iam_member.writers : key => binding.member }
}

output "repository_name" {
  description = "Nom complet du dépôt Artifact Registry"
  value       = google_artifact_registry_repository.docker.id
}

output "docker_registry_host" {
  description = "Hôte Docker à configurer pour l'authentification"
  value       = "${var.region}-docker.pkg.dev"
}

output "docker_repository_url" {
  description = "Préfixe des images Docker, sans protocole HTTPS"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

