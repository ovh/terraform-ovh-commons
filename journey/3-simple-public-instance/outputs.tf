output "helper" {
  description = "human friendly helper"
  value = <<DESC
You can now connect to your instance:

 $ ssh centos@${openstack_compute_instance_v2.instance.access_ip_v4}
DESC
}
