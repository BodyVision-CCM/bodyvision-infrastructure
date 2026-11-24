resource "google_project_service" "required" {
  for_each           = toset(["sqladmin.googleapis.com", "servicenetworking.googleapis.com"])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_global_address" "private_services" {
  project       = var.project_id
  name          = "bodyvision-${var.environment}-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network_id
}

resource "google_service_networking_connection" "private_services" {
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
  depends_on              = [google_project_service.required]
}

resource "google_sql_database_instance" "this" {
  project             = var.project_id
  name                = "bodyvision-${var.environment}-postgres"
  region              = var.region
  database_version    = "POSTGRES_16"
  deletion_protection = var.deletion_protection
  settings {
    # Session start/stop is managed with gcloud, independently of persistent applies.
    activation_policy           = var.activation_policy
    tier                        = "db-custom-1-3840"
    edition                     = "ENTERPRISE"
    availability_type           = "ZONAL"
    disk_type                   = "PD_SSD"
    disk_size                   = 10
    disk_autoresize             = true
    disk_autoresize_limit       = 20
    deletion_protection_enabled = var.deletion_protection
    ip_configuration {
      ipv4_enabled       = false
      private_network    = var.network_id
      allocated_ip_range = google_compute_global_address.private_services.name
      ssl_mode           = "ENCRYPTED_ONLY"
    }
    backup_configuration {
      enabled                        = true
      start_time                     = "02:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }
  }
  lifecycle {
    ignore_changes = [settings[0].activation_policy]
  }
  depends_on = [google_service_networking_connection.private_services]
}

resource "google_sql_database" "bodyvision" {
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = "bodyvision"
  # Persisted in state: removing this resource must only forget the database.
  deletion_policy = "ABANDON"
}
