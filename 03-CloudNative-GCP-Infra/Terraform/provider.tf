terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # =========================================================================
  # CRITICAL: Commented out for Step 1. We will uncomment this in Step 2!
  # =========================================================================
  # backend "gcs" {
  #   bucket = "tony-bookstore-tfstate-bucket" # Change to a globally unique name
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}