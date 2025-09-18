# Create lookup maps for dashboard URLs
locals {
  outputs_lxc_meta = yamldecode(file("${path.module}/config/meta.yml")).lxc
  outputs_vm_meta  = yamldecode(file("${path.module}/config/meta.yml")).vm
  
  lxc_dashboards = {
    for config in local.outputs_lxc_meta :
    config.container_name => lookup(config, "dashboard", "")
  }
  
  vm_dashboards = {
    for config in local.outputs_vm_meta :
    config.vm_name => lookup(config, "dashboard", "")
  }
  
  lxc_ids = {
    for config in local.outputs_lxc_meta :
    config.container_name => config.container_id
  }
}

# Timestamp of the last deployment
output "deployment_timestamp" {
  description = "Timestamp of the last deployment"
  value       = timestamp()
}

# Consolidated VM details - successfully deployed only
output "vms" {
  description = "Successfully deployed VMs with details"
  value = {
    for name, vm in module.vms :
    name => merge(
      {
        name = name
        id   = vm.vm_id
      },
      lookup(local.vm_dashboards, name, "") != "" ? { dashboard = lookup(local.vm_dashboards, name, "") } : {}
    )
    if try(vm.vm_id, "") != ""
  }
}

# Consolidated LXC details - successfully deployed only
output "lxcs" {
  description = "Successfully deployed LXC containers with details"
  value = {
    for name, lxc in module.lxcs :
    name => merge(
      {
        name = name
        id   = lookup(local.lxc_ids, name, "")
        deployed = try(lxc.run_id, "")
      },
      lookup(local.lxc_dashboards, name, "") != "" ? { dashboard = lookup(local.lxc_dashboards, name, "") } : {}
    )
    if try(lxc.run_id, "") != ""
  }
}
