data "openstack_networking_network_v2" "vrack" {
  name = var.name
}

resource "openstack_networking_subnet_v2" "vrack" {
  name            = var.name
  network_id      = data.openstack_networking_network_v2.vrack.id
  cidr            = var.subnet_cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
  enable_dhcp     = true
  no_gateway      = true
}

resource "openstack_networking_port_v2" "vrack" {
  name           = "${var.name}-bastion-vrack"
  network_id     = data.openstack_networking_network_v2.vrack.id
  admin_state_up = "true"

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.vrack.id
  }
}

data "openstack_networking_network_v2" "ext_net" {
  name      = "Ext-Net"
  tenant_id = ""
}

resource "openstack_networking_secgroup_v2" "bastion_sg" {
  name        = "${var.name}_bastion"
  description = "${var.name} security group for bastion hosts"
}

resource "openstack_networking_secgroup_rule_v2" "bastion_in_ssh" {
  count             = length(var.remote_ssh_prefixes)
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = tolist(var.remote_ssh_prefixes)[count.index]
  security_group_id = openstack_networking_secgroup_v2.bastion_sg.id
}

resource "openstack_networking_port_v2" "fip" {
  name           = "${var.name}-bastion-pub"
  network_id     = data.openstack_networking_network_v2.ext_net.id
  admin_state_up = "true"

  security_group_ids = [
    openstack_networking_secgroup_v2.bastion_sg.id
  ]
}

resource "openstack_compute_instance_v2" "bastion" {
  name        = "${var.name}-bastion"
  image_name  = var.bastion_image_name
  flavor_name = var.bastion_flavor_name
  key_pair    = var.ssh_keypair

  network {
    port           = openstack_networking_port_v2.fip.id
    access_network = true
  }

  network {
    port = openstack_networking_port_v2.vrack.id
  }

  lifecycle {
    ignore_changes = [user_data, image_name, image_id]
  }

  user_data = <<EOF
#cloud-config
write_files:
 - path: /etc/systemd/network/10-ens3.network
   permissions: '0644'
   content: |
    [Match]
    Name=ens3 eth0
    [Network]
    DHCP=ipv4
    [DHCP]
    # favor ens3 default routes over ens4
    RouteMetric=1024
 - path: /etc/systemd/network/20-ens4.network
   permissions: '0644'
   content: |
    [Match]
    Name=ens4 eth1
    [Network]
    DHCP=ipv4
    [DHCP]
    # favor ens3 default routes over ens4
    RouteMetric=2048
runcmd:
  - sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
  - systemctl restart systemd-networkd sshd
EOF
}
