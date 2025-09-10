# Timestamp of the last deployment
output "deployment_timestamp" {
  description = "Timestamp of the last deployment"
  value       = timestamp()
}

# Infrastructure summary - fully dynamic
output "infrastructure_summary" {
  description = "Summary of resource status"
  value = {
    vms = {
      for name, vm in module.vms :
      name => try(vm.vm_status, "") != "" ? "deployed" : "failed"
    },
    lxcs = {
      for name, lxc in module.lxcs :
      name => try(lxc.container_status, "") != "" ? "deployed" : "failed"
    }
  }
}

# Details of all VMs - fully dynamic
output "vm_details" {
  description = "Details of all deployed VMs"
  value = {
    for name, vm in module.vms :
    name => try(vm.vm_name != "", false) ? {
      name        = vm.vm_name
      id          = vm.vm_id
      ip_address  = vm.ip_address
      mac_address = vm.mac_address
      status      = vm.vm_status
    } : null
  }
}

# Details of all LXC containers - fully dynamic
output "lxc_details" {
  description = "Details of all deployed LXC containers"
  value = {
    for name, lxc in module.lxcs :
    name => try(lxc.container_name != "", false) ? {
      name          = lxc.container_name
      id            = lxc.container_id
      mac_address   = lxc.mac_address
      status        = lxc.container_status
      startup_order = lxc.startup_order
    } : null
  }
}

# Individual output for each VM for easy access
output "vms" {
  description = "Direct access to all VMs by name"
  value = {
    for name, vm in module.vms : name => {
      name       = try(vm.vm_name, "")
      id         = try(vm.vm_id, "")
      ip_address = try(vm.ip_address, [])
      status     = try(vm.vm_status, "")
    }
  }
}

# Individual output for each LXC container for easy access
output "lxcs" {
  description = "Direct access to all LXC containers by name"
  value = {
    for name, lxc in module.lxcs : name => {
      name   = try(lxc.container_name, "")
      id     = try(lxc.container_id, "")
      status = try(lxc.container_status, "")
    }
  }
}
