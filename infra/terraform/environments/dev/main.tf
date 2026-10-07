module "network" {
  source = "../../modules/network"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  network_name    = "bodyvision-${var.environment}-vpc"
  subnetwork_name = "bodyvision-${var.environment}-subnet"

  subnetwork_cidr = var.subnetwork_cidr

  pods_secondary_range_name = "bodyvision-${var.environment}-pods"
  pods_secondary_cidr       = var.pods_secondary_cidr

  services_secondary_range_name = "bodyvision-${var.environment}-services"
  services_secondary_cidr       = var.services_secondary_cidr
}

module "iam" {
  source = "../../modules/iam"

  project_id  = var.project_id
  environment = var.environment
}

module "gke" {
  source = "../../modules/gke"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  cluster_name = "bodyvision-${var.environment}-gke"

  network_id                    = module.network.network_id
  subnetwork_id                 = module.network.subnetwork_id
  pods_secondary_range_name     = module.network.pods_secondary_range_name
  services_secondary_range_name = module.network.services_secondary_range_name

  master_ipv4_cidr_block = var.master_ipv4_cidr_block
  node_locations         = var.node_locations

  node_service_account_email = module.iam.gke_nodes_service_account_email

  machine_type   = var.gke_machine_type
  disk_size_gb   = 50
  min_node_count = var.gke_min_node_count
  max_node_count = var.gke_max_node_count

  master_authorized_networks = var.master_authorized_networks

  deletion_protection = false
}

resource "google_service_account_iam_member" "observability_workload_identity" {
  service_account_id = module.iam.observability_service_account_name
  role               = "roles/iam.workloadIdentityUser"

  member = "serviceAccount:${module.gke.workload_identity_pool}[bodyvision/observability]"

  depends_on = [
    module.gke,
  ]
}