# define a remote state backend on swift
terraform {
  backend "swift" {
    container = "demo-public-instance"
  }
}

# configure your ovh provider
provider "ovh" {
  version  = "~> 0.2"
  endpoint = "ovh-eu"
}

# configure your openstack provider to the first region
provider "openstack" {
  version = "~> 1.2"
  alias   = "regionA"
  region  = "${var.region_a}"
}

# configure your openstack provider to the second region
provider "openstack" {
  version = "~> 1.2"
  alias   = "regionB"
  region  = "${var.region_b}"
}

# Import Keypair by inlining your ssh public key using terraform interpolation 
# primitives (https://www.terraform.io/docs/configuration/interpolation.html)
# Import Keypair in both regions
resource "openstack_compute_keypair_v2" "keypair_a" {
  provider   = "openstack.regionA"
  name       = "${var.name}"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

resource "openstack_compute_keypair_v2" "keypair_b" {
  provider   = "openstack.regionB"
  name       = "${var.name}"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

###
# Creation of the multiregion vrack network
###
resource "ovh_publiccloud_private_network" "net" {
  project_id = "${var.os_tenant_id}"
  name       = "${var.name}"
  regions    = ["${var.region_a}", "${var.region_b}"]
  vlan_id    = "111"
}


# create the network in region A
module "network_a" {
  source  = "ovh/publiccloud-network/ovh"
  version = ">= 0.1.0"

  network_name    = "${ovh_publiccloud_private_network.net.name}"
  create_network  = false
  name            = "${var.name}"
  cidr            = "${var.cidr}"
  region          = "${var.region_a}"

  # public subnets shall host instances with a public netif
  # such as NATs, bastions, vpns, load balancers, ...
  public_subnets  = ["${cidrsubnet(var.cidr, 8, 0)}"]

  # private subnets shall host backend instances. The dhcp agents
  # will push a default route through the according NAT gateway
  private_subnets = ["${cidrsubnet(var.cidr, 8, 1)}"]

  enable_nat_gateway = true
  single_nat_gateway = true
  nat_as_bastion     = true

  # the bastion host will receive the following ssh public keys
  ssh_public_keys = ["${openstack_compute_keypair_v2.keypair_a.public_key}"]

  providers = {
    "openstack" = "openstack.regionA"
  }
}

# create the network in region B
module "network_b" {
  source  = "ovh/publiccloud-network/ovh"
  version = ">= 0.1.0"

  network_name    = "${ovh_publiccloud_private_network.net.name}"
  create_network  = false
  name            = "${var.name}"
  cidr            = "${var.cidr}"
  region          = "${var.region_b}"

  # public subnets shall host instances with a public netif
  # such as NATs, bastions, vpns, load balancers, ...
  public_subnets  = ["${cidrsubnet(var.cidr, 8, 2)}"]

  # private subnets shall host backend instances. The dhcp agents
  # will push a default route through the according NAT gateway
  private_subnets = ["${cidrsubnet(var.cidr, 8, 3)}"]

  # ssh access to our instances in region B will go through the bastion host
  # in region A. No need for a bastion host here.
  enable_nat_gateway = true
  single_nat_gateway = true
  ssh_public_keys = []

  providers = {
    "openstack" = "openstack.regionB"
  }
}

# get NATed IP to allow ssh only from terraform host
data "http" "myip" {
  url = "https://api.ipify.org/"
}

# allow remote ssh connection only for terraform host on region A
resource "openstack_networking_secgroup_rule_v2" "in_traffic_ssh_a" {
  provider          = "openstack.regionA"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "${trimspace(data.http.myip.body)}/32"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = "${module.network_a.nat_security_group_id}"
}
###
# instances region A
###

# create an anti-affinity server group.
# WARNING: You can't boot more than 5
# servers in one server group
resource "openstack_compute_servergroup_v2" "group_a" {
  provider = "openstack.regionA"
  name     = "${var.name}_a"
  policies = ["anti-affinity"]
}

# create subnet ports that will be attached to instances
resource "openstack_networking_port_v2" "ports_a" {
  provider       = "openstack.regionA"
  count          = "${var.count}"
  name           = "${var.name}_a_${count.index}"
  network_id     = "${module.network_a.network_id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${module.network_a.private_subnets[0]}"
  }
}

resource "openstack_compute_instance_v2" "instances_a" {
  provider    = "openstack.regionA"
  count       = "${var.count}"
  name        = "${var.name}_a_${count.index}"
  image_name  = "Centos 7"
  flavor_name = "s1-8"
  key_pair    = "${openstack_compute_keypair_v2.keypair_a.name}"

  user_data = <<USERDATA
#cloud-config
# add route to global network
bootcmd:
 - ip route add ${var.cidr} dev eth0 scope link metric 0
USERDATA

  network {
    port           = "${element(openstack_networking_port_v2.ports_a.*.id, count.index)}"
    access_network = true
  }

  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.group_a.id}"
  }
}

###
# instances region B
###

# create an anti-affinity server group.
# WARNING: You can't boot more than 5
# servers in one server group
resource "openstack_compute_servergroup_v2" "group_b" {
  provider = "openstack.regionB"
  name     = "${var.name}_b"
  policies = ["anti-affinity"]
}

# create subnet ports that will be attached to instances
resource "openstack_networking_port_v2" "ports_b" {
  provider       = "openstack.regionB"
  count          = "${var.count}"
  name           = "${var.name}_b_${count.index}"
  network_id     = "${module.network_b.network_id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${module.network_b.private_subnets[0]}"
  }
}

resource "openstack_compute_instance_v2" "instances_b" {
  provider    = "openstack.regionB"
  count       = "${var.count}"
  name        = "${var.name}_b_${count.index}"
  image_name  = "Centos 7"
  flavor_name = "s1-8"
  key_pair    = "${openstack_compute_keypair_v2.keypair_b.name}"

  user_data = <<USERDATA
#cloud-config
# add route to global network
bootcmd:
 - ip route add ${var.cidr} dev eth0 scope link metric 0
USERDATA

  network {
    port           = "${element(openstack_networking_port_v2.ports_b.*.id, count.index)}"
    access_network = true
  }

  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.group_b.id}"
  }
}
