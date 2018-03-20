output "helper" {
  description = "human friendly helper"
  value = <<DESC
You can now connect to your instances in region A:
   ${indent(3, join("\n", formatlist("$ ssh -J core@%s centos@%s", module.network_a.bastion_public_ip, openstack_compute_instance_v2.instances_a.*.access_ip_v4)))}

You can now connect to your instances in region B:
   ${indent(3, join("\n", formatlist("$ ssh -J core@%s centos@%s", module.network_b.bastion_public_ip, openstack_compute_instance_v2.instances_b.*.access_ip_v4)))}
DESC
}
