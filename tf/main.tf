terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

data "google_project" "current-project" {
  project_id = var.project_id
}

# Grant the Vertex AI service agent and Reasoning Engine service agent network permissions
resource "google_project_iam_member" "aiplatform_network_admin" {
  project = var.project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:service-${data.google_project.current-project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "aiplatform_re_network_admin" {
  project = var.project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:service-${data.google_project.current-project.number}@gcp-sa-aiplatform-re.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "aiplatform_network_user" {
  project = var.project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:service-${data.google_project.current-project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "aiplatform_re_network_user" {
  project = var.project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:service-${data.google_project.current-project.number}@gcp-sa-aiplatform-re.iam.gserviceaccount.com"
}

# Grant default compute service account necessary runtime roles
resource "google_project_iam_member" "compute_sa_aiplatform_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${data.google_project.current-project.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "compute_sa_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${data.google_project.current-project.number}-compute@developer.gserviceaccount.com"
}

resource "google_compute_subnetwork_iam_member" "subnet_re_network_user" {
  project    = var.project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.attachment-subnet.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:service-${data.google_project.current-project.number}@gcp-sa-aiplatform-re.iam.gserviceaccount.com"
}

resource "google_compute_subnetwork_iam_member" "subnet_aiplatform_network_user" {
  project    = var.project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.attachment-subnet.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:service-${data.google_project.current-project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
}

resource "google_compute_subnetwork_iam_member" "subnet_servicenetworking_network_user" {
  project    = var.project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.attachment-subnet.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:service-${data.google_project.current-project.number}@service-networking.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "servicenetworking_network_user" {
  project = var.project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:service-${data.google_project.current-project.number}@service-networking.iam.gserviceaccount.com"
}

# Grant DNS Peer role to Vertex AI & Reasoning Engine service agents for Private DNS resolution
resource "google_project_iam_member" "aiplatform_dns_peer" {
  project = var.project_id
  role    = "roles/dns.peer"
  member  = "serviceAccount:service-${data.google_project.current-project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "aiplatform_re_dns_peer" {
  project = var.project_id
  role    = "roles/dns.peer"
  member  = "serviceAccount:service-${data.google_project.current-project.number}@gcp-sa-aiplatform-re.iam.gserviceaccount.com"
}

# create vpc, subnet, network attachment
resource "google_compute_network" "attachment-vpc" {
  name                    = "attachment-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_firewall" "allow_internal_and_health_checks" {
  name    = "attachment-vpc-allow-ingress"
  network = google_compute_network.attachment-vpc.name

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_egress" {
  name      = "attachment-vpc-allow-egress"
  network   = google_compute_network.attachment-vpc.name
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
}

resource "google_compute_subnetwork" "attachment-subnet" {
  name                     = "attachment-subnet"
  ip_cidr_range            = var.attachment_subnet_cidr
  region                   = var.region
  network                  = google_compute_network.attachment-vpc.id
  private_ip_google_access = true
}

resource "google_compute_network_attachment" "agent-engine-network-attachment" {
  name                  = "agent-engine-network-attachment"
  region                = var.region
  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [google_compute_subnetwork.attachment-subnet.id]
}

# Private Service Connect Google APIs Endpoint
resource "google_compute_global_address" "psc_google_apis_ip" {
  name         = "psc-google-apis-ip"
  address_type = "INTERNAL"
  purpose      = "PRIVATE_SERVICE_CONNECT"
  network      = google_compute_network.attachment-vpc.id
  address      = "10.250.0.1"
}

resource "google_compute_global_forwarding_rule" "psc_google_apis" {
  name                  = "pscgoogleapis"
  target                = "all-apis"
  network               = google_compute_network.attachment-vpc.id
  ip_address            = google_compute_global_address.psc_google_apis_ip.id
  load_balancing_scheme = ""
}

# Private Cloud DNS Zone for googleapis.com -> PSC Google APIs IP
resource "google_dns_managed_zone" "googleapis" {
  name        = "googleapis-private-zone"
  dns_name    = "googleapis.com."
  description = "Private DNS zone routing googleapis.com to PSC endpoint"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.attachment-vpc.id
    }
  }
}

resource "google_dns_record_set" "googleapis_a" {
  name         = "googleapis.com."
  managed_zone = google_dns_managed_zone.googleapis.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.psc_google_apis_ip.address]
}

resource "google_dns_record_set" "googleapis_cname" {
  name         = "*.googleapis.com."
  managed_zone = google_dns_managed_zone.googleapis.name
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["googleapis.com."]
}

# NAT for internet access
resource "google_compute_address" "attachment-nat-ip" {
  name   = "attachment-nat-ip"
  region = var.region
}

resource "google_compute_router" "attachment-router" {
  name    = "attachment-router"
  region  = var.region
  network = google_compute_network.attachment-vpc.id
}

resource "google_compute_router_nat" "attachment_nat" {
  name                               = "attachment-nat"
  router                             = google_compute_router.attachment-router.name
  region                             = var.region
  nat_ip_allocate_option             = "MANUAL_ONLY"
  nat_ips                            = [google_compute_address.attachment-nat-ip.self_link]
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Proxy VM for outbound internet access
resource "google_compute_instance" "proxy_vm" {
  name         = "proxy-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.attachment-subnet.id
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  metadata = {
    startup-script = <<-EOF
      #!/bin/bash
      sudo apt-get update
      sudo apt-get install -y tcpdump tinyproxy apache2
      sudo service apache2 restart
      echo 'proxy server !!' | sudo tee /var/www/html/index.html

      # Configure tinyproxy to allow connections from internal subnets
      sudo sed -i 's/^Allow /#Allow /' /etc/tinyproxy/tinyproxy.conf
      echo "Allow 0.0.0.0/0" | sudo tee -a /etc/tinyproxy/tinyproxy.conf
      sudo systemctl restart tinyproxy
    EOF
  }
}

output "proxy_vm_internal_ip" {
  description = "Internal IP address of the proxy VM"
  value       = google_compute_instance.proxy_vm.network_interface[0].network_ip
}

