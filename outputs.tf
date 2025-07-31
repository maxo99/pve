# Test outputs to verify variable loading
output "proxmox_api_url" {
  description = "Shows the loaded Proxmox API URL"
  value       = var.proxmox_api_url
}

output "proxmox_user" {
  description = "Shows the loaded Proxmox user"
  value       = var.proxmox_user
}

output "proxmox_password" {
  description = "Shows if password is set (masked for security)"
  value       = var.proxmox_password != "your-password" ? "✓ Custom password set" : "⚠ Using default placeholder"
  sensitive   = true
}

output "ci_ipconfig" {
  description = "Shows the Cloud-Init IP configuration"
  value       = var.ci_ipconfig
}

output "ci_username" {
  description = "Shows the Cloud-Init username"
  value       = var.ci_username
}
