data "google_compute_default_service_account" "default" {}

# =========================================================================
# RESOURCE 1: The Remote GCS State Storage Vault
# =========================================================================
resource "google_storage_bucket" "tf_state_bucket" {
  name          = "tony-bookstore-tfstate-bucket" # MUST match the provider block string exactly
  location      = "US"
  force_destroy = false # Acts as the master infrastructure safeguard line

  storage_class = "STANDARD"
  
  versioning {
    enabled = true # Keeps histories of your state changes to prevent state corruption
    }

  lifecycle {
    prevent_destroy = true # Safeguard: Terraform will completely block anyone from running destroy on this bucket
  }
}

# =========================================================================
# RESOURCE 2: The Production Compute Engine Instance
# =========================================================================
resource "google_compute_instance" "bookstore_vm" {
  name         = "bookstore-production-vm"
  machine_type = "e2-medium" # Provides stable RAM overhead for multi-stage execution loops
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  # Maps the VM onto your default VPC network topology interface
  network_interface {
    network = "default"
    access_config {
      # Leaving this block completely blank assigns a dynamic public External IP
    }
  }

  # =========================================================================
  # SECURITY: Allow Full API Scopes to completely clear the token cache error
  # =========================================================================
  service_account {
    # Dynamically reads the native project service account email
    email  = data.google_compute_default_service_account.default.email
    scopes = ["cloud-platform"]
  }

  # =========================================================================
  # RUNTIME: The Automated Startup Script Layer
  # =========================================================================
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -x
    # 1. Install Docker Engine and core dependencies
    sudo apt-get update
    sudo apt-get install -y docker.io docker-compose-v2 git

    # 2. Securely fetch your API token from Secret Manager into memory
    LIVE_KEY=$(gcloud secrets versions access latest --secret="GEMINI_KEY" --format="value(payload.data)")
    
    # 3. Pull down your project repository directly onto the application server
    cd /home/ubuntu
    git clone https://github.com/TonyStark0542/PersonalProject.git
    cd PersonalProject/01-Bookstore-Monolith/

    # 4. Create the backup folder and move your archive inside it
    # (Assuming your db_backup.archive is tracked inside your git repo)
    mkdir -p database_backup
    mv db_backup.archive database_backup/

    # 5. Launch the entire application stack!
    # We pass the memory key inline so it injects right as Docker initializes
    GEMINI_API_KEY=$LIVE_KEY docker compose up -d

    # 6. Wait 10 seconds for MongoDB to initialize, then seed the data
    sleep 10
    docker exec -i mongodb-backend mongorestore --archive=/backup/db_backup.archive
  EOT

  tags = ["http-server", "bookstore-app-node"]
}

# =========================================================================
# RESOURCE 3: Firewall Rule to Open Port 5000 for Public Web Traffic
# =========================================================================
resource "google_compute_firewall" "allow_flask_traffic" {
  name    = "allow-bookstore-flask-port"
  network = "default" # Binds this rule straight onto your default VPC network layout

  # Defines the structural flow rule parameter mapping
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["0.0.0.0/0"] # Open to the public internet so users can browse the store

  allow {
    protocol = "tcp"
    ports    = ["5000"] # Opens the precise execution port your Dockerfile exposes
  }

  # =========================================================================
  # TARGET TAGS: The Network Gluing Mechanism
  # =========================================================================
  # This rule will ONLY apply to virtual machines that carry this exact tag string!
  target_tags = ["bookstore-app-node"]
}