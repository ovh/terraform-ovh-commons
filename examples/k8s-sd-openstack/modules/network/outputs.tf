output "network_id" {
  description = "Id of the network"
  value       = data.openstack_networking_network_v2.vrack.id
}

output "subnet_id" {
  description = "Id of the subnet"
  value       = openstack_networking_subnet_v2.vrack.id
}

output "bastion_sg_id" {
  description = "Id of the subnet"
  value       = openstack_networking_secgroup_v2.bastion_sg.id
}

output "bastion_ipv4" {
  description = "IPV4 of the bastion host"
  value       = openstack_compute_instance_v2.bastion.access_ip_v4
}
