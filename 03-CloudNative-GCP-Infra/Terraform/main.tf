# =========================================================================
# 1. RUNTIME API BOOTSTRAPPER & NATIVE SERVICE ACCOUNT DATA SOURCE
# =========================================================================
resource "null_resource" "enable_api_bootstrap" {
  provisioner "local-exec" {
    command = "gcloud services enable iam.googleapis.com"
  }
}

data "google_compute_default_service_account" "default" {
  depends_on = [null_resource.enable_api_bootstrap]
}

# =========================================================================
# 2. THE INFRASTRUCTURE STATE BUCKET
# =========================================================================
#resource "google_storage_bucket" "tf_state_bucket" {
#  name          = "tony-bookstore-tfstate-bucket-${var.gcp_project_id}"
#  location      = "US"
#  force_destroy = false
#  storage_class = "STANDARD"
#  
#  versioning {
#    enabled = true
#  }
#  lifecycle {
#    prevent_destroy = true
#  }
#}

# =========================================================================
# 3. PRODUCTION APPLICATION VM NODE
# =========================================================================
resource "google_compute_instance" "bookstore_vm" {
  name         = "bookstore-production-vm"
  machine_type = var.machine_type
  zone         = var.gcp_zone

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
        
    # 2. Pull down your project repository directly onto the application server
    cd /home/ubuntu
    git clone https://github.com/TonyStark0542/PersonalProject.git
    cd PersonalProject/01-Bookstore-Monolith/
    
    # 3. Launch the entire application stack passing the pre-fetched key
    # AUTOMATION: Terraform writes the .env file directly onto the production disk!
    echo "GEMINI_API_KEY=${var.gemini_api_key}" > .env

    # Launch the containers cleanly with the file in place
    sudo docker compose up -d
    
    # 4. Wait for MongoDB initialization, then seed data
    sleep 10
    docker exec -i mongodb-backend mongorestore --archive=/backup/db_backup.archive --gzip
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
    ports    = [var.app_port]
  }

  target_tags = ["bookstore-app-node"]
}
