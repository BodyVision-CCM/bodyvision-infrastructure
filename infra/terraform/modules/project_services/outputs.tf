output "enabled_services" {
  description = "Liste des API gérées par le module"
  value       = sort(keys(google_project_service.this))
}