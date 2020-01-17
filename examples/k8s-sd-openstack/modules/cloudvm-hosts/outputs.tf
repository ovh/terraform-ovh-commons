output "hosts" {
  description = "List of hosts"
  value = [
    for s in openstack_compute_instance_v2.node[*] :
    {
      name        = s.name
      public_ipv4 = [for i in s.network : i.fixed_ip_v4 if i.access_network][0]
      vrack_ipv4  = [for i in s.network : i.fixed_ip_v4 if ! i.access_network][0]
    }
  ]
}

output "public_ipv4_list" {
  description = "List of floating IP addresses"
  value = [
    for ips in openstack_networking_port_v2.fip[*].all_fixed_ips :
    [
      for ip in ips :
      ip
      if length(replace(ip, "/[[:alnum:]]+:[^,]+/", "")) > 0
    ][0]
  ]
}

output "vrack_ipv4_list" {
  description = "List of Vrack IP addresses"
  value = [
    for ips in openstack_networking_port_v2.priv[*].all_fixed_ips :
    [
      for ip in ips :
      ip
      if length(replace(ip, "/[[:alnum:]]+:[^,]+/", "")) > 0
    ][0]
  ]
}
