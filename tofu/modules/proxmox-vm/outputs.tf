output "vm_id" {
  description = "ID della VM creata"
  value       = proxmox_virtual_environment_vm.vm.id
}

output "vm_name" {
  description = "Nome della VM creata"
  value       = proxmox_virtual_environment_vm.vm.name
}

output "ip_address" {
  description = "Indirizzo IP assegnato alla VM (se disponibile)"
  value       = proxmox_virtual_environment_vm.vm.ipv4_addresses
}

output "mac_address" {
  description = "MAC address dell'interfaccia di rete"
  value       = proxmox_virtual_environment_vm.vm.network_device[0].mac_address
}

output "vm_status" {
  description = "Stato corrente della VM"
  value       = proxmox_virtual_environment_vm.vm.started ? "running" : "stopped"
}
