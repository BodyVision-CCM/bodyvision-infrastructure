locals {
  required_services = toset([
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudtrace.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ])
}

module "project_services" {
  source = "../modules/project_services"

  project_id = var.project_id
  services   = local.required_services
}

resource "google_storage_bucket" "terraform_state" {
  name     = "${var.project_id}-bodyvision-tfstate"
  project  = var.project_id
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  labels = {
    application = "bodyvision"
    managed_by  = "terraform"
    purpose     = "terraform-state"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [module.project_services]
}