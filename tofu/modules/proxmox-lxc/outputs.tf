output "container_id" {
  description = "ID of created container"
  value       = proxmox_virtual_environment_container.lxc.id
}

output "container_name" {
  description = "Name of created container"
  value       = proxmox_virtual_environment_container.lxc.initialization[0].hostname
}

output "mac_address" {
  description = "MAC address of the network interface"
  value       = proxmox_virtual_environment_container.lxc.network_interface[0].mac_address
}

output "container_status" {
  description = "Current container status"
  value       = proxmox_virtual_environment_container.lxc.started ? "running" : "stopped"
}

output "run_id" {
  description = "Unique run identifier for this deployment"
  value       = var.run_id
}

output "status_directory" {
  description = "Path to the status directory on Proxmox host"
  value       = "/tmp/${var.run_id}-lxc-${var.container_id}-status"
}

output "startup_order" {
  description = "Startup order of the container"
  value       = proxmox_virtual_environment_container.lxc.startup[0].order
}