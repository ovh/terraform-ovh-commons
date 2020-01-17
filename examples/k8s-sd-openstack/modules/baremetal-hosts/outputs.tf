output "hosts" {
  description = "List of hosts"
  value = [
    for s in keys(var.hosts) :
    {
      name        = var.hosts[s]
      public_ipv4 = data.ovh_dedicated_server.server[s].ip
      vrack_ipv4  = openstack_networking_port_v2.vrack[s].all_fixed_ips[0]
    }
  ]
}

output "vrack_ipv4_list" {
  description = "List of Vrack IPV4 addresses"
  value = [
    for s in keys(var.hosts) : openstack_networking_port_v2.vrack[s].all_fixed_ips[0]
  ]
}

output "public_ipv4_list" {
  description = "List of Public IPV4 addresses"
  value = [
    for s in keys(var.hosts) : data.ovh_dedicated_server.server[s].ip
  ]
}
