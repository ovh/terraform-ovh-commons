resource "openstack_networking_network_v2" "vrack" {
  admin_state_up = "true"
  name           = var.name

  value_specs = {
    "provider:network_type"    = "vrack"
    "provider:segmentation_id" = var.vlan_id
  }
}

resource "openstack_networking_subnet_v2" "vrack" {
  cidr            = var.network_cidr
  dns_nameservers = ["8.8.8.8"]
  enable_dhcp     = true
  ip_version      = 4
  name            = var.name
  network_id      = openstack_networking_network_v2.vrack.id
  no_gateway      = true

  allocation_pool {
    start = cidrhost(var.subnet_cidr, 1)
    end   = cidrhost(var.subnet_cidr, -1)
  }
}

resource "openstack_networking_port_v2" "ports" {
  count = var.nb_hosts

  admin_state_up = "true"
  name           = "${var.name}-${count.index}"
  network_id     = openstack_networking_network_v2.vrack.id

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.vrack.id
  }
}

resource "openstack_compute_keypair_v2" "keypair" {
  name       = var.name
  public_key = var.ssh_public_key
}

resource "openstack_compute_instance_v2" "hosts" {
  count = var.nb_hosts

  flavor_name = var.flavor_name
  image_name  = var.image_name
  key_pair    = openstack_compute_keypair_v2.keypair.name
  name        = "${var.name}-${count.index}"

  network {
    port = openstack_networking_port_v2.ports[count.index].id
  }
}
