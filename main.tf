terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.31.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.31.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
provider "google-beta" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type        = string
  description = "Google Cloud Project ID"
}
variable "region" {
  type    = string
  default = "us-central1"
}
variable "network_name" {
  type = string
}
variable "subnet_name" {
  type = string
}

# import {
#   provider = google-beta
#   id       = "projects/${var.project_id}/global/networks/${var.network_name}"
#   to       = google_compute_network.default
# }

# import {
#   provider = google-beta
#   id       = "projects/${var.project_id}/regions/${var.region}/subnetworks/${var.subnet_name}"
#   to       = google_compute_subnetwork.default
# }
resource "google_compute_network" "default" {
  provider                = google-beta
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

data "google_compute_subnetwork" "default" {
  depends_on = [google_compute_network.default]
  provider   = google-beta
  project    = var.project_id
  region     = var.region
  name       = var.subnet_name
}

resource "google_compute_subnetwork" "default" {
  depends_on                       = [google_compute_network.default, data.google_compute_subnetwork.default]
  provider                         = google-beta
  project                          = var.project_id
  network                          = google_compute_network.default.self_link
  region                           = data.google_compute_subnetwork.default.region
  name                             = data.google_compute_subnetwork.default.name
  private_ip_google_access         = data.google_compute_subnetwork.default.private_ip_google_access
  ip_cidr_range                    = data.google_compute_subnetwork.default.ip_cidr_range
  purpose                          = "PRIVATE" // not available in the data source?
  send_secondary_ip_range_if_empty = true

  secondary_ip_range {
    range_name              = "gke-pods-1"
    reserved_internal_range = "networkconnectivity.googleapis.com/${google_network_connectivity_internal_range.gke_pods_1.id}"
  }
  secondary_ip_range {
    range_name              = "gke-services-1"
    reserved_internal_range = "networkconnectivity.googleapis.com/${google_network_connectivity_internal_range.gke_services_1.id}"
  }
  secondary_ip_range {
    range_name              = "gke-pods-2"
    reserved_internal_range = "networkconnectivity.googleapis.com/${google_network_connectivity_internal_range.gke_pods_2.id}"
  }
  secondary_ip_range {
    range_name              = "gke-services-2"
    reserved_internal_range = "networkconnectivity.googleapis.com/${google_network_connectivity_internal_range.gke_services_2.id}"
  }
}

resource "google_network_connectivity_internal_range" "gke_pods_1" {
  provider      = google-beta
  project       = var.project_id
  network       = google_compute_network.default.id
  usage         = "FOR_VPC"
  peering       = "FOR_SELF"
  name          = "gke-pods-1"
  ip_cidr_range = "10.2.0.0/18"
}

resource "google_network_connectivity_internal_range" "gke_pods_2" {
  provider      = google-beta
  project       = var.project_id
  network       = google_compute_network.default.id
  usage         = "FOR_VPC"
  peering       = "FOR_SELF"
  name          = "gke-pods-2"
  ip_cidr_range = "10.2.64.0/18"
}

resource "google_network_connectivity_internal_range" "gke_services_1" {
  provider      = google-beta
  project       = var.project_id
  network       = google_compute_network.default.id
  usage         = "FOR_VPC"
  peering       = "FOR_SELF"
  name          = "gke-services-1"
  ip_cidr_range = "10.2.128.0/20"
}

resource "google_network_connectivity_internal_range" "gke_services_2" {
  provider      = google-beta
  project       = var.project_id
  network       = google_compute_network.default.id
  usage         = "FOR_VPC"
  peering       = "FOR_SELF"
  name          = "gke-services-2"
  ip_cidr_range = "10.2.144.0/20"
}

output "gke_reserved_ranges" {
  value = {
    for range in [
      google_network_connectivity_internal_range.gke_pods_1,
      google_network_connectivity_internal_range.gke_pods_2,
      google_network_connectivity_internal_range.gke_services_1,
      google_network_connectivity_internal_range.gke_services_2,
    ] : range.name => range
  }
}

output "gke_subnet" {
  value = data.google_compute_subnetwork.default
}
