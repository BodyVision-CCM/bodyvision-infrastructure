output "state_bucket_name" {
  description = "Nom du bucket contenant les états Terraform"
  value       = google_storage_bucket.terraform_state.name
}

output "enabled_services" {
  description = "Liste des API activées"
  value       = module.project_services.enabled_services
}