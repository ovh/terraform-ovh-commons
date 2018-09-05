output "instance_ids" {
  value = ["${openstack_compute_instance_v2.node.*.id}"]
}
