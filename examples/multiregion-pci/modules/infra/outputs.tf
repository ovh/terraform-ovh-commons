output "hosts" {
  description = "hosts"
  value       = openstack_compute_instance_v2.hosts
}

output "network" {
  description = "vrack network"
  value       = openstack_networking_network_v2.vrack
}

output "keypair" {
  description = "keypair name"
  value       = openstack_compute_keypair_v2.keypair.name
}
