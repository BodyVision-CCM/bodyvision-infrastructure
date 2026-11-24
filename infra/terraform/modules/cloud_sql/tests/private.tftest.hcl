mock_provider "google" {}

variables {
  project_id  = "bodyvision-test"
  environment = "dev"
  network_id  = "projects/bodyvision-test/global/networks/bodyvision-dev-vpc"
}

run "private_database_contract" {
  command = plan
  assert {
    condition     = google_sql_database_instance.this.settings[0].activation_policy == "NEVER"
    error_message = "L'instance doit être arrêtée hors session par défaut."
  }
  assert {
    condition     = google_sql_database_instance.this.database_version == "POSTGRES_16" && google_sql_database_instance.this.region == "europe-west9"
    error_message = "PostgreSQL 16 doit rester dans la région prévue."
  }
  assert {
    condition     = !google_sql_database_instance.this.settings[0].ip_configuration[0].ipv4_enabled && google_sql_database_instance.this.settings[0].ip_configuration[0].private_network == var.network_id
    error_message = "Cloud SQL doit rester privé dans le VPC demandé."
  }
  assert {
    condition     = google_sql_database_instance.this.settings[0].backup_configuration[0].enabled && google_sql_database_instance.this.settings[0].backup_configuration[0].point_in_time_recovery_enabled
    error_message = "Les sauvegardes et la restauration temporelle sont obligatoires."
  }
  assert {
    condition     = google_sql_database_instance.this.deletion_protection && google_sql_database_instance.this.settings[0].deletion_protection_enabled
    error_message = "Les protections contre suppression doivent être activées par défaut."
  }
  assert {
    condition     = google_sql_database.bodyvision.deletion_policy == "ABANDON"
    error_message = "La base bodyvision ne doit jamais être supprimée par Terraform : deletion_policy = ABANDON."
  }
  assert {
    condition     = coalesce(google_sql_database_instance.this.settings[0].disk_autoresize_limit, 0) > 0
    error_message = "L'agrandissement automatique du disque doit être plafonné : un disque ne rétrécit jamais."
  }
}

# Mock state only: a later persistent plan must preserve a running session.
run "running_session" {
  command = apply
  variables {
    activation_policy = "ALWAYS"
  }
}

run "persistent_plan_preserves_running_session" {
  command = plan
  assert {
    condition     = google_sql_database_instance.this.settings[0].activation_policy == "ALWAYS"
    error_message = "Un plan avec NEVER par défaut ne doit pas arrêter une session démarrée."
  }
}
