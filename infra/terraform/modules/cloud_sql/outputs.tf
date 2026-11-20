output "connection_name" {
  description = "Nom de connexion pour Cloud SQL Auth Proxy"
  value       = google_sql_database_instance.this.connection_name
}
output "private_ip_address" {
  description = "IP privée pour les Network Policies"
  value       = google_sql_database_instance.this.private_ip_address
}
output "database_name" {
  description = "Base applicative"
  value       = google_sql_database.bodyvision.name
}
