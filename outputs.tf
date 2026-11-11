output "ip" {
  description = "Static public IPv4 of the VM. Point the DNS A record for actual_fqdn here (Cloudflare: DNS only / grey cloud)."
  value       = google_compute_address.container_host.address
}

output "actual_url" {
  value = "https://${var.actual_fqdn}"
}

output "backup_bucket" {
  value = google_storage_bucket.backups.name
}
