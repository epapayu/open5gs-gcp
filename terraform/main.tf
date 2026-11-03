# ==============================================================================
# Open5GS 5G Standalone (5G SA) Core on Google Cloud Platform
# Reference Terraform Blueprint (Multi-VPC + GKE Dataplane V2 + Firestore + Memorystore)
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.30.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.30.0"
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

# ------------------------------------------------------------------------------
# 1. Multi-VPC Network Fabric (SBI, N2, N3, N4, N6)
# ------------------------------------------------------------------------------

# 1A. Primary VPC: Service-Based Interface (HTTP/2 SBI) & Management
resource "google_compute_network" "vpc_sbi" {
  name                    = "vpc-sbi-mgmt"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "subnet_sbi" {
  name                     = "subnet-sbi"
  ip_cidr_range            = "10.10.0.0/20"
  region                   = var.region
  network                  = google_compute_network.vpc_sbi.id
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods-sbi"
    ip_cidr_range = "10.100.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services-sbi"
    ip_cidr_range = "10.200.0.0/20"
  }
}

# Cloud Router & Cloud NAT on SBI/Management VPC for GKE Node Container Image Pulls
resource "google_compute_router" "sbi_router" {
  name    = "open5gs-sbi-router"
  region  = var.region
  network = google_compute_network.vpc_sbi.id
}

resource "google_compute_router_nat" "sbi_nat" {
  name                               = "open5gs-sbi-nat"
  router                             = google_compute_router.sbi_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# 1B. N2 VPC: gNodeB -> AMF NGAP over SCTP (:38412)
resource "google_compute_network" "vpc_n2" {
  name                    = "vpc-n2-signaling"
  auto_create_subnetworks = false
  mtu                     = 1500
}

resource "google_compute_subnetwork" "subnet_n2" {
  name          = "subnet-n2"
  ip_cidr_range = "10.20.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_n2.id

  secondary_ip_range {
    range_name    = "pods-n2"
    ip_cidr_range = "10.120.0.0/20"
  }
}

# 1C. N3 VPC: gNodeB <-> UPF GTP-U User Plane (:2152) - Jumbo MTU 8896
resource "google_compute_network" "vpc_n3" {
  name                    = "vpc-n3-userplane"
  auto_create_subnetworks = false
  mtu                     = 8896
}

resource "google_compute_subnetwork" "subnet_n3" {
  name          = "subnet-n3"
  ip_cidr_range = "10.30.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_n3.id

  secondary_ip_range {
    range_name    = "pods-n3"
    ip_cidr_range = "10.130.0.0/20"
  }
}

# 1D. N4 VPC: SMF <-> UPF PFCP Session Control (:8805) - Jumbo MTU 8896
resource "google_compute_network" "vpc_n4" {
  name                    = "vpc-n4-pfcp"
  auto_create_subnetworks = false
  mtu                     = 8896
}

resource "google_compute_subnetwork" "subnet_n4" {
  name          = "subnet-n4"
  ip_cidr_range = "10.40.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_n4.id

  secondary_ip_range {
    range_name    = "pods-n4"
    ip_cidr_range = "10.140.0.0/20"
  }
}

# 1E. N6 VPC: UPF -> External Data Network (DN / Internet Breakout)
resource "google_compute_network" "vpc_n6" {
  name                    = "vpc-n6-dn"
  auto_create_subnetworks = false
  mtu                     = 1500
}

resource "google_compute_subnetwork" "subnet_n6" {
  name          = "subnet-n6"
  ip_cidr_range = "10.60.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_n6.id

  secondary_ip_range {
    range_name    = "pods-n6"
    ip_cidr_range = "10.160.0.0/20"
  }
}

# Cloud Router & Cloud NAT on N6 VPC for UE Internet Breakout
resource "google_compute_router" "n6_router" {
  name    = "open5gs-n6-router"
  region  = var.region
  network = google_compute_network.vpc_n6.id
}

resource "google_compute_router_nat" "n6_nat" {
  name                               = "open5gs-n6-nat"
  router                             = google_compute_router.n6_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# ------------------------------------------------------------------------------
# 2. 3GPP Protocol Firewall Rules (N2/S1-MME SCTP, N3/S1-U GTP-U, N4/Sxa PFCP, GTPv2-C)
# ------------------------------------------------------------------------------

resource "google_compute_firewall" "allow_n2_s1mme_sctp" {
  name    = "allow-n2-s1mme-sctp"
  network = google_compute_network.vpc_n2.name

  allow {
    protocol = "sctp"
    # 38412 = 5G N2 NGAP, 36412 = 4G S1-MME S1AP, 29118 = SGsAP
    ports = ["38412", "36412", "29118"]
  }

  allow {
    protocol = "udp"
    # 2123 = GTPv2-C (N26 AMF<->MME, S11 MME<->SGW-C, S5c SGW-C<->SMF/PGW-C)
    ports = ["2123"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.ran_cidr, "10.20.0.0/24", "10.120.0.0/20"]
}

resource "google_compute_firewall" "allow_n3_gtpu" {
  name    = "allow-n3-gtpu-udp"
  network = google_compute_network.vpc_n3.name

  allow {
    protocol = "udp"
    ports    = ["2152"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [var.ran_cidr, "10.30.0.0/24", "10.130.0.0/20"]
}

resource "google_compute_firewall" "allow_n4_pfcp" {
  name    = "allow-n4-pfcp-udp"
  network = google_compute_network.vpc_n4.name

  allow {
    protocol = "udp"
    ports    = ["8805"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.40.0.0/24", "10.140.0.0/20"]
}

# Cloud Armor WAF Security Policy for Open5GS NMS WebUI (BackendConfig)
resource "google_compute_security_policy" "nms_cloud_armor" {
  name        = "open5gs-nms-cloud-armor-policy"
  description = "Cloud Armor WAF security policy protecting Open5GS WebUI NMS"
}

# ------------------------------------------------------------------------------
# 3. GKE Standard Regional Cluster with Dataplane V2 & Multi-Networking
# ------------------------------------------------------------------------------

resource "google_container_cluster" "open5gs_cluster" {
  provider = google-beta
  name     = "open5gs-5gc-cluster"
  location = var.region

  network    = google_compute_network.vpc_sbi.id
  subnetwork = google_compute_subnetwork.subnet_sbi.id

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  node_config {
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  # Private GKE Nodes (uses Cloud NAT on vpc-sbi-mgmt; complies with vmExternalIpAccess org policies)
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.17.0.0/28"
  }

  # Enable Dataplane V2 (Cilium eBPF) + Multi-Networking for N2/N3/N4/N6 NICs
  datapath_provider = "ADVANCED_DATAPATH"

  enable_multi_networking = true

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods-sbi"
    services_secondary_range_name = "services-sbi"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Native Google Cloud Managed Service for Prometheus (GMP) & GKE Workload/Deployment Telemetry
  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "APISERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER",
      "STORAGE",
      "HPA",
      "POD",
      "DAEMONSET",
      "DEPLOYMENT",
      "STATEFULSET",
      "KUBELET",
      "CADVISOR",
    ]
    managed_prometheus {
      enabled = true
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  lifecycle {
    ignore_changes = [node_config]
  }
}

# 3A. Control Plane Node Pool (NRF, SCP, AUSF, UDM, UDR, PCF, NSSF, BSF, SEPP, WebUI)
resource "google_container_node_pool" "control_plane_pool" {
  provider   = google-beta
  name       = "sba-control-plane-pool"
  location   = var.region
  cluster    = google_container_cluster.open5gs_cluster.name
  node_count = 1

  node_locations = var.zones

  node_config {
    machine_type = "n2-standard-8"
    image_type   = "COS_CONTAINERD"

    labels = {
      "5g-plane" = "control-plane-sba"
    }

    gvnic {
      enabled = true
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

# 3B. Multi-NIC Telco Edge/Dataplane Node Pool (AMF, SMF, UPF)
resource "google_container_node_pool" "multinic_dataplane_pool" {
  provider   = google-beta
  name       = "upf-amf-multinic-pool"
  location   = var.region
  cluster    = google_container_cluster.open5gs_cluster.name
  node_count = 1

  node_locations = [var.zones[0], var.zones[1]]

  # Attach Secondary VPC NICs & Pod Alias Ranges for 3GPP N2, N3, N4, and N6 isolation
  network_config {
    enable_private_nodes = true

    additional_node_network_configs {
      network    = google_compute_network.vpc_n2.name
      subnetwork = google_compute_subnetwork.subnet_n2.name
    }

    additional_node_network_configs {
      network    = google_compute_network.vpc_n3.name
      subnetwork = google_compute_subnetwork.subnet_n3.name
    }

    additional_node_network_configs {
      network    = google_compute_network.vpc_n4.name
      subnetwork = google_compute_subnetwork.subnet_n4.name
    }

    additional_node_network_configs {
      network    = google_compute_network.vpc_n6.name
      subnetwork = google_compute_subnetwork.subnet_n6.name
    }

    additional_pod_network_configs {
      subnetwork          = google_compute_subnetwork.subnet_n2.name
      secondary_pod_range = tolist(google_compute_subnetwork.subnet_n2.secondary_ip_range)[0].range_name
      max_pods_per_node   = 16
    }

    additional_pod_network_configs {
      subnetwork          = google_compute_subnetwork.subnet_n3.name
      secondary_pod_range = tolist(google_compute_subnetwork.subnet_n3.secondary_ip_range)[0].range_name
      max_pods_per_node   = 16
    }

    additional_pod_network_configs {
      subnetwork          = google_compute_subnetwork.subnet_n4.name
      secondary_pod_range = tolist(google_compute_subnetwork.subnet_n4.secondary_ip_range)[0].range_name
      max_pods_per_node   = 16
    }

    additional_pod_network_configs {
      subnetwork          = google_compute_subnetwork.subnet_n6.name
      secondary_pod_range = tolist(google_compute_subnetwork.subnet_n6.secondary_ip_range)[0].range_name
      max_pods_per_node   = 16
    }
  }

  node_config {
    machine_type = "c3-standard-8"
    image_type   = "UBUNTU_CONTAINERD"

    labels = {
      "5g-plane" = "multinic-dataplane"
    }

    gvnic {
      enabled = true
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

# ------------------------------------------------------------------------------
# 4. Persistence & In-Memory Data Layer (Firestore MongoDB Compat & Memorystore)
# ------------------------------------------------------------------------------

# 4A. Cloud Firestore Enterprise with MongoDB Compatibility (Subscriber & Policy DB)
resource "google_firestore_database" "open5gs_mongodb_compat" {
  provider                            = google-beta
  project                             = var.project_id
  name                                = "open5gs-db"
  location_id                         = var.region
  type                                = "FIRESTORE_NATIVE"
  database_edition                    = "ENTERPRISE"
  firestore_data_access_mode          = "DATA_ACCESS_MODE_DISABLED"
  mongodb_compatible_data_access_mode = "DATA_ACCESS_MODE_ENABLED"
  deletion_policy                     = "DELETE"
  point_in_time_recovery_enablement   = "POINT_IN_TIME_RECOVERY_ENABLED"
}

# 4A-2. SCRAM-SHA-256 Database Credentials & IAM Binding for Open5GS NFs / WebUI
resource "google_firestore_user_creds" "open5gs_db_user" {
  provider = google-beta
  project  = var.project_id
  database = google_firestore_database.open5gs_mongodb_compat.name
  name     = "open5gs-user"
}

resource "google_project_iam_member" "open5gs_db_user_owner" {
  project = var.project_id
  role    = "roles/datastore.owner"
  member  = google_firestore_user_creds.open5gs_db_user.resource_identity[0].principal
}

# 4B. Cloud Memorystore for Redis/Valkey (NMS Session Cache, Policy Cache, UDSF Store)
resource "google_redis_instance" "open5gs_inmemory_cache" {
  name               = "open5gs-inmemory-cache"
  tier               = "STANDARD_HA"
  memory_size_gb     = 5
  region             = var.region
  authorized_network = google_compute_network.vpc_sbi.id
  redis_version      = "REDIS_7_2"
  display_name       = "Open5GS NMS & Session State Cache"
  transit_encryption_mode = "SERVER_AUTHENTICATION"
}
