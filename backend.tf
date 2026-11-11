terraform {
  # State is kept in a local file (terraform.tfstate, gitignored) instead of
  # HCP Terraform. It contains secrets: don't commit it.

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.25"
    }
  }
}
