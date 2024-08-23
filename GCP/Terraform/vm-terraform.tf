terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">2.0"
    }
  }
  required_version = ">= 1.4.0"
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}