# define a remote state backend on swift
terraform {
  backend "swift" {
    container = "demo-public-instance"
  }
}

# configure your openstack provider to target the region of your choice
provider "openstack" {
  region = "${var.region}"
}

# Import Keypair by inlining your ssh public key using terraform interpolation 
# primitives (https://www.terraform.io/docs/configuration/interpolation.html)
resource "openstack_compute_keypair_v2" "keypair" {
  name       = "${var.name}"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

# get NATed IP to allow ssh only from terraform host
data "http" "myip" {
  url = "https://api.ipify.org"
}

# create the security group to which the instances & ports will be associated
resource "openstack_networking_secgroup_v2" "sg" {
  name        = "${var.name}_ssh_sg"
  description = "${var.name} security group"
}

# allow remote ssh connection only for terraform host
resource "openstack_networking_secgroup_rule_v2" "in_traffic_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "${trimspace(data.http.myip.body)}/32"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = "${openstack_networking_secgroup_v2.sg.id}"
}

# allow ingress traffic inter instances
resource "openstack_networking_secgroup_rule_v2" "ingress_instances" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = "${openstack_networking_secgroup_v2.sg.id}"
  security_group_id = "${openstack_networking_secgroup_v2.sg.id}"
}

# allow egress traffic worldwide
resource "openstack_networking_secgroup_rule_v2" "egress_instances" {
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.sg.id}"
}

# create an anti-affinity server group.
# WARNING: You can't boot more than 5
# servers in one server group
resource "openstack_compute_servergroup_v2" "group" {
  name     = "${var.name}"
  policies = ["anti-affinity"]
}

# use a data source to retrieve Ext-Net network id for your target region
data "openstack_networking_network_v2" "ext_net" {
  name      = "Ext-Net"
  tenant_id = ""
}

# create a port before the instances allows you
# to keep your IP when you taint an instance
resource "openstack_networking_port_v2" "public_port" {
  count = "${var.count}"

  name               = "${var.name}_${count.index}"
  network_id         = "${data.openstack_networking_network_v2.ext_net.id}"
  admin_state_up     = "true"

  # the security groups are attached to the ports, not the instance.
  security_group_ids = ["${openstack_networking_secgroup_v2.sg.id}"]
}

# create instances
resource "openstack_compute_instance_v2" "instances" {
  # instance count : same as port count
  count           = "${var.count}"
  # name the instances according to the count number
  name            = "${var.name}_${count.index}"

  # Choose your base image from our catalog
  image_name  = "Centos 7"

  # Choose a flavor type
  flavor_name = "s1-8"

  # Target your brand new keypair
  key_pair    = "${openstack_compute_keypair_v2.keypair.name}"

  # Attach your VM to the according ports
  network {
    port           = "${element(openstack_networking_port_v2.public_port.*.id, count.index)}"
    access_network = true
  }

  # Place the instances in the constrained server group
  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.group.id}"
  }
}
