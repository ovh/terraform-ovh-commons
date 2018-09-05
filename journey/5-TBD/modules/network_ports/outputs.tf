output "public_port_ids" {
  value = ["${openstack_networking_port_v2.public.*.id}"]
}

output "admin_port_ids" {
  value = ["${openstack_networking_port_v2.admin.*.id}"]
}

output "admin_port_ipv4s" {
  value = ["${flatten(openstack_networking_port_v2.admin.*.all_fixed_ips)}"]
}

output "public_port_ipv4s" {
  value = ["${flatten(openstack_networking_port_v2.public.*.all_fixed_ips)}"]
}
