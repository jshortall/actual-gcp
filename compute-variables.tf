variable "actual_fqdn" {
  type        = string
  description = "FQDN of actual server to use for certificate generation"
}

variable "container_host_network_tags" {
  type        = list(string)
  description = "List of network tags to add for firewall rules"
}

variable "actual_image" {
  type        = string
  description = "Container image for the Actual sync server (built from your fork by its fork-image workflow)"
  default     = "ghcr.io/jshortall/actual-server:latest"
}

variable "google_oauth_client_id" {
  type        = string
  description = "OAuth 2.0 client ID (Web application) for Google sign-in. Authorized redirect URI: https://<actual_fqdn>/openid/callback"
}

variable "google_oauth_client_secret" {
  type        = string
  description = "OAuth 2.0 client secret for Google sign-in"
  sensitive   = true
}

variable "session_lifetime_seconds" {
  type        = number
  description = "How long a sign-in lasts before Google sign-in is needed again (Actual reads ACTUAL_TOKEN_EXPIRATION as seconds for OpenID logins)"
  default     = 2592000 # 30 days
}

variable "backup_retention_days" {
  type        = number
  description = "Days to keep nightly backups in the bucket"
  default     = 30
}

variable "public_key_path" {
  type    = string
  default = "~/.ssh/id_gcp_ed25519.pub"
}

variable "public_key" {
  type        = string
  description = "SSH public key to use if public key file doesn't exist (if running in HCP Terraform)"
  default     = ""
}

variable "user" {
  type = string
}

variable "vm_image_family" {
  type        = string
  description = "Family of image to use with VM creation"
}

variable "vm_image_project" {
  type        = string
  description = "Project to which the image belongs."
}

variable "vm_size" {
  type        = string
  description = "VM instance type."
}
