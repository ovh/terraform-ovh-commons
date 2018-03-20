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

# allow egress traffic worldwide
resource "openstack_networking_secgroup_rule_v2" "egress_instances" {
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.sg.id}"
}

# private network (be sure a vrack has been attached to your openstack tenant
# otherwise this resource will fail)
resource "openstack_networking_network_v2" "net" {
  name           = "${var.name}"
  admin_state_up = "true"
}

# create the subnet in which the instances will be spawned
resource "openstack_networking_subnet_v2" "subnet" {
  network_id = "${openstack_networking_network_v2.net.id}"
  cidr       = "${var.cidr}"
  ip_version = 4

  # dhcp is required if you want to be able to retrieve metadata from
  # the 169.254.169.254 because the route is pushed via dhcp
  enable_dhcp = true

  # this attribute is set for doc purpose only : GW are not used within OVH
  # network as it's a layer 2 network. Instead, you have to setup your
  # routes properly on each instances
  no_gateway = true

  # ovh dns, then google dns. order matters
  dns_nameservers = ["213.186.33.99", "8.8.8.8"]

  allocation_pools {
    # you can subdivise your network with terraform interpolation primitives
    # be aware that a dhcp agent will take one IP within the allocation pool
    start = "${cidrhost(var.cidr,2)}"
    end   = "${cidrhost(var.cidr,-2)}"
  }
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
  network_id     = "${openstack_networking_network_v2.net.id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.subnet.id}"
  }
}

resource "openstack_compute_instance_v2" "instances" {
  count           = "${var.count}"
  name            = "${var.name}_${count.index}"
  image_name      = "Centos 7"
  flavor_name     = "s1-8"
  key_pair        = "${openstack_compute_keypair_v2.keypair.name}"
  security_groups = ["${openstack_networking_secgroup_v2.sg.name}"]

  network {
    port           = "${element(openstack_networking_port_v2.ports.*.id, count.index)}"
    access_network = true
  }

  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.group.id}"
  }
}

####
#  bastion host
###
# use a data source to retrieve Ext-Net network id for your target region
data "openstack_networking_network_v2" "ext_net" {
  name      = "Ext-Net"
  tenant_id = ""
}

# create a port before the instances allows you
# to keep your IP when you taint an instance
resource "openstack_networking_port_v2" "bastion_public_port" {
  name               = "${var.name}_bastion_pub"
  network_id         = "${data.openstack_networking_network_v2.ext_net.id}"
  admin_state_up     = "true"

  # attach a security group on the public port to filter access
  security_group_ids = ["${openstack_networking_secgroup_v2.sg.id}"]
}

# create a port before the instances allows you
# to keep your IP when you taint an instance
resource "openstack_networking_port_v2" "bastion_private_port" {
  name           = "${var.name}_bastion_priv"
  network_id     = "${openstack_networking_network_v2.net.id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.subnet.id}"
  }
}

# launch the bastion host
resource "openstack_compute_instance_v2" "bastion" {
  name            = "${var.name}_bastion"
  image_name      = "Centos 7"
  flavor_name     = "s1-2"
  key_pair        = "${openstack_compute_keypair_v2.keypair.name}"
  security_groups = ["${openstack_networking_secgroup_v2.sg.name}"]

  # Inject userdata into the bastion host to automatically
  # bring both network interfaces on boot
  user_data = <<USERDATA
#cloud-config
# add ncat to allow ssh proxy commands
runcmd:
 - yum install -y nmap-ncat
# enable eth1
bootcmd:
 - dhclient eth1
USERDATA

  # attach the private port on eth0
  network {
    port = "${openstack_networking_port_v2.bastion_private_port.id}"
  }

  # attach the public port on eth1
  network {
    port           = "${openstack_networking_port_v2.bastion_public_port.id}"
    access_network = true
  }
}
