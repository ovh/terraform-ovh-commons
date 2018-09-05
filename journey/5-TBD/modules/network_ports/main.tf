data "openstack_networking_network_v2" "public" {
  name = "${var.public_network_name}"
}

resource "openstack_networking_subnet_v2" "public" {
  network_id  = "${data.openstack_networking_network_v2.public.id}"
  cidr        = "${var.public_cidr}"
  ip_version  = 4
  name        = "${var.name}_public_subnet"
  gateway_ip  = "${var.public_gateway}"
  enable_dhcp = true

  dns_nameservers = ["${var.dns_nameservers}"]

  allocation_pools {
    start = "${var.public_subnet_pool_start}"
    end   = "${var.public_subnet_pool_end}"
  }
}

data "openstack_networking_network_v2" "admin" {
  name = "${var.admin_network_name}"
}

resource "openstack_networking_subnet_v2" "admin" {
  network_id  = "${data.openstack_networking_network_v2.admin.id}"
  cidr        = "${var.admin_cidr}"
  ip_version  = 4
  name        = "${var.name}_admin_subnet"
  enable_dhcp = true
  no_gateway  = true

  allocation_pools {
    start = "${var.admin_subnet_pool_start}"
    end   = "${var.admin_subnet_pool_end}"
  }
}

resource "openstack_networking_port_v2" "admin" {
  count          = "${var.count}"
  name           = "${var.name}"
  network_id     = "${openstack_networking_subnet_v2.admin.network_id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.admin.id}"
  }
}

resource "openstack_networking_port_v2" "public" {
  count          = "${var.count}"
  name           = "${var.name}"
  network_id     = "${openstack_networking_subnet_v2.public.network_id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.public.id}"
  }
}
