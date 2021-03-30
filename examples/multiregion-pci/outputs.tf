output "bastion_pub_ipv4" {
  value = openstack_compute_instance_v2.bastion.access_ip_v4
}

output "hosts" {
  value = {
    for h in concat(module.hosts-one.hosts, module.hosts-two.hosts, module.hosts-three.hosts) :
    h.name => h.access_ip_v4
  }
}
