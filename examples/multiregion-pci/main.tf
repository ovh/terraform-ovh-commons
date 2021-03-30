provider "openstack" {
  cloud  = "mycloud"
  region = var.region_one
  alias  = "one"
}

provider "openstack" {
  cloud  = "mycloud"
  region = var.region_two
  alias  = "two"
}

provider "openstack" {
  cloud  = "mycloud"
  region = var.region_three
  alias  = "three"
}

module "hosts-one" {
  source = "./modules/infra"

  flavor_name    = "c2-7"
  image_name     = "Debian 10"
  name           = "${var.name}-one"
  nb_hosts       = 1
  network_cidr   = var.network_cidr
  ssh_public_key = var.ssh_public_key
  subnet_cidr    = cidrsubnet(var.network_cidr, 4, 0)
  vlan_id        = 100

  providers = {
    openstack = openstack.one
  }
}

module "hosts-two" {
  source = "./modules/infra"

  flavor_name    = "c2-7"
  image_name     = "Debian 10"
  name           = "${var.name}-two"
  nb_hosts       = 1
  network_cidr   = var.network_cidr
  ssh_public_key = var.ssh_public_key
  subnet_cidr    = cidrsubnet(var.network_cidr, 4, 1)
  vlan_id        = 100

  providers = {
    openstack = openstack.two
  }
}

module "hosts-three" {
  source = "./modules/infra"

  flavor_name    = "c2-7"
  image_name     = "Debian 10"
  name           = "${var.name}-three"
  nb_hosts       = 1
  network_cidr   = var.network_cidr
  ssh_public_key = var.ssh_public_key
  subnet_cidr    = cidrsubnet(var.network_cidr, 4, 2)
  vlan_id        = 100

  providers = {
    openstack = openstack.three
  }
}

data "openstack_networking_network_v2" "ext_net" {
  name      = "Ext-Net"
  tenant_id = ""

  provider = openstack.one
}

resource "openstack_networking_port_v2" "bastion-extnet" {
  admin_state_up = "true"
  name           = "${var.name}-bastion-ext"
  network_id     = data.openstack_networking_network_v2.ext_net.id

  provider = openstack.one
}

resource "openstack_compute_instance_v2" "bastion" {
  name        = "${var.name}-bastion"
  image_name  = "Debian 10"
  flavor_name = "c2-7"
  key_pair    = module.hosts-one.keypair

  network {
    port           = openstack_networking_port_v2.bastion-extnet.id
    access_network = true
  }

  network {
    name = module.hosts-one.network.name
  }

  provider = openstack.one
}
