# =========================================================================
# 1. READ SECRET ON CONTROLLER (Using an External Data Source Hook)
# =========================================================================
# Since your controller already has full access to the secret, we fetch it here
data "external" "fetch_gemini_key" {
  program = ["sh", "-c", "echo \"{\\\"key\\\":\\\"$(gcloud secrets versions access latest --secret=GEMINI_KEY --format='value(payload.data)')\\\"}\""]
}

data "google_compute_default_service_account" "default" {}

# =========================================================================
# 2. THE INFRASTRUCTURE STATE BUCKET
# =========================================================================
resource "google_storage_bucket" "tf_state_bucket" {
  name          = "tony-bookstore-tfstate-bucket"
  location      = "US"
  force_destroy = false
  storage_class = "STANDARD"
  
  versioning {
    enabled = true
  }
  lifecycle {
    prevent_destroy = true
  }
}

# =========================================================================
# 3. PRODUCTION APPLICATION VM NODE
# =========================================================================
resource "google_compute_instance" "bookstore_vm" {
  name         = "bookstore-production-vm"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  service_account {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["cloud-platform"]
  }

  # =========================================================================
  # RUNTIME WORKAROUND: Injecting the Key Directly Into the Script
  # =========================================================================
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -x
    # 1. Install Docker Engine and core dependencies
    sudo apt-get update
    sudo apt-get install -y docker.io docker-compose-v2 git
    
    # 2. INJECTED WORKAROUND: Terraform drops the raw key text directly here!
    LIVE_KEY="${data.external.fetch_gemini_key.result.key}"
        
    # 3. Pull down your project repository directly onto the application server
    cd
    git clone https://github.com/TonyStark0542/PersonalProject.git
    cd PersonalProject/01-Bookstore-Monolith/
    
    # 5. Launch the entire application stack passing the pre-fetched key
    GEMINI_API_KEY=$LIVE_KEY docker compose up -d
    
    # 6. Wait for MongoDB initialization, then seed data
    sleep 10
    docker exec -i mongodb-backend mongorestore --archive=/backup/db_backup.archive
  EOT

  tags = ["http-server", "bookstore-app-node"]
}

# =========================================================================
# 4. NETWORKING PERIMETER FIREWALL GATE
# =========================================================================
resource "google_compute_firewall" "allow_flask_traffic" {
  name          = "allow-bookstore-flask-port"
  network       = "default"
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }

  target_tags = ["bookstore-app-node"]
}