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

###
# Use of the OVH network module
###
module "network" {
  source = "ovh/publiccloud-network/ovh"
  version = ">= 0.1.0"

  name            = "${var.name}"
  cidr            = "${var.cidr}"
  region          = "${var.region}"

  # public subnets shall host instances with a public netif
  # such as NATs, bastions, vpns, load balancers, ...
  public_subnets  = ["${cidrsubnet(var.cidr, 4, 0)}"]

  # private subnets shall host backend instances. The dhcp agents
  # will push a default route through the according NAT gateway
  private_subnets = ["${cidrsubnet(var.cidr, 4, 1)}"]

  enable_nat_gateway = true
  enable_bastion_host  = true

  # the bastion host will receive the following ssh public keys
  ssh_public_keys = ["${openstack_compute_keypair_v2.keypair.public_key}"]
}

# get NATed IP to allow ssh only from terraform host
data "http" "myip" {
  url = "https://api.ipify.org"
}


# allow remote ssh connection only for terraform host
resource "openstack_networking_secgroup_rule_v2" "in_traffic_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "${data.http.myip.body}/32"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = "${module.network.nat_security_group_id}"
}

# create an anti-affinity server group.
# WARNING: You can't boot more than 5
# servers in one server group
resource "openstack_compute_servergroup_v2" "group" {
  name     = "${var.name}"
  policies = ["anti-affinity"]
}

# create subnet ports that will be attached to instances
resource "openstack_networking_port_v2" "ports" {
  count          = "${var.count}"
  name           = "${var.name}_${count.index}"
  network_id     = "${module.network.network_id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${module.network.private_subnets[0]}"
  }
}

resource "openstack_compute_instance_v2" "instances" {
  count           = "${var.count}"
  name            = "${var.name}_${count.index}"
  image_name      = "Centos 7"
  flavor_name     = "s1-8"
  key_pair        = "${openstack_compute_keypair_v2.keypair.name}"

  network {
    port           = "${element(openstack_networking_port_v2.ports.*.id, count.index)}"
    access_network = true
  }

  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.group.id}"
  }
}
