output "id" {
  description = "id of the security group"
  value       = openstack_networking_secgroup_v2.secgroup.id
}
