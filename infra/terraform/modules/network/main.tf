resource "google_compute_network" "this" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "this" {
  project                  = var.project_id
  name                     = var.subnetwork_name
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.subnetwork_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = var.pods_secondary_range_name
    ip_cidr_range = var.pods_secondary_cidr
  }

  secondary_ip_range {
    range_name    = var.services_secondary_range_name
    ip_cidr_range = var.services_secondary_cidr
  }
}

resource "google_compute_router" "this" {
  project = var.project_id
  name    = "bodyvision-${var.environment}-router"
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  project = var.project_id
  name    = "bodyvision-${var.environment}-nat"
  region  = var.region
  router  = google_compute_router.this.name

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_firewall" "allow_internal" {
  project = var.project_id
  name    = "bodyvision-${var.environment}-allow-internal"
  network = google_compute_network.this.name

  direction = "INGRESS"
  priority  = 1000

  source_ranges = [
    var.subnetwork_cidr,
    var.pods_secondary_cidr,
    var.services_secondary_cidr,
  ]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}