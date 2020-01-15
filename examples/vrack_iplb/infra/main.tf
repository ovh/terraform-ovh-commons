terraform {
  required_version = ">= 0.12.0"
  required_providers {
    openstack = ">= 1.20"
    ovh       = ">= 0.6"
  }
}

provider openstack {
  region = var.region
}

provider ovh {
  endpoint = "ovh-eu"
}

data openstack_networking_network_v2 vrack {
  name = var.name
}

resource openstack_compute_keypair_v2 keypair {
  name       = var.name
  public_key = file(var.ssh_pubkey_path)
}


resource openstack_networking_subnet_v2 subnet {
  name       = var.name
  network_id = data.openstack_networking_network_v2.vrack.id

  # specify the global network so the route to the iplb subnet is available
  cidr            = var.subnet
  ip_version      = 4
  enable_dhcp     = true
  gateway_ip      = cidrhost(var.subnet_nodes, 1)
  dns_nameservers = ["213.186.33.99"]

  allocation_pool {
    start = cidrhost(var.subnet_nodes, 2)
    end   = cidrhost(var.subnet_nodes, -2)
  }
}

resource openstack_networking_port_v2 bastion_vrack {
  name           = "${var.name}-bastion-vrack"
  network_id     = data.openstack_networking_network_v2.vrack.id
  admin_state_up = "true"

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.subnet.id
    ip_address = cidrhost(var.subnet_nodes, 1)
  }
}
