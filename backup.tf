# Nightly backups of /mnt/disks/data/actual-data (see actual-backup.sh in locals.tf).
# Standard storage in us-central1 is within the free tier (5 GB-months); backups are
# a few MB each and are deleted after backup_retention_days.
resource "google_storage_bucket" "backups" {
  name                        = "${data.google_project.project.project_id}-actual-backups"
  location                    = upper(var.gcp_region)
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle_rule {
    condition {
      age = var.backup_retention_days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.project]
}

# Create-only: a compromised VM can add backups but not read, overwrite or delete them.
resource "google_storage_bucket_iam_member" "backup_writer" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.container_host.email}"
}
