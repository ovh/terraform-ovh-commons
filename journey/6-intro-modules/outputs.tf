output "helper" {
  description = "human friendly helper"
  value = <<DESC
You can now connect to your instances:
   ${indent(3, join("\n", formatlist("$ ssh -J core@%s centos@%s", module.network.bastion_public_ip, openstack_compute_instance_v2.instances.*.access_ip_v4)))}
DESC
}
