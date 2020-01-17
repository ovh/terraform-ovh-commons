data "openstack_images_image_v2" "image" {
  name        = var.image_name
  most_recent = true
}

data "openstack_networking_network_v2" "ext_net" {
  name      = var.floating_ip_pool
  tenant_id = ""
}

data "openstack_networking_subnet_v2" "vrack" {
  subnet_id    = var.subnet_id
  ip_version   = 4
  dhcp_enabled = true
}

resource "openstack_networking_port_v2" "fip" {
  count          = var.assign_floating_ip ? var.nb : 0
  name           = "${var.name}_fip"
  network_id     = data.openstack_networking_network_v2.ext_net.id
  admin_state_up = "true"

  security_group_ids = [
    var.secgroup_id
  ]
}

resource "openstack_networking_port_v2" "priv" {
  count          = var.nb
  name           = "${var.name}_priv"
  network_id     = data.openstack_networking_subnet_v2.vrack.network_id
  admin_state_up = "true"

  fixed_ip {
    subnet_id = var.subnet_id
  }
}

# Create instance
resource "openstack_compute_instance_v2" "node" {
  count       = var.nb
  name        = "${var.name}-${format("%03d", count.index)}"
  image_id    = data.openstack_images_image_v2.image.id
  flavor_name = var.flavor_name
  key_pair    = var.keypair


  # Important: orders of network declaration matters because
  # public network is attached on eth1, so keep it at the end of the list

  # vrack port on ens3/eth0
  network {
    port           = openstack_networking_port_v2.priv[count.index].id
    access_network = ! var.assign_floating_ip
  }

  # fip port on ens4/eth1 if assign_floating_ip is true
  dynamic "network" {
    for_each = ! var.assign_floating_ip ? [] : [
      {
        port           = openstack_networking_port_v2.fip[count.index].id
        access_network = true
      }
    ]

    content {
      port           = network.value.port
      access_network = network.value.access_network
    }
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
    # favor ens4 default routes over ens3
    RouteMetric=2048
 - path: /etc/systemd/network/20-ens4.network
   permissions: '0644'
   content: |
    [Match]
    Name=ens4 eth1
    [Network]
    DHCP=ipv4
    [DHCP]
    # favor ens4 default routes over ens3
    RouteMetric=1024
runcmd:
  - sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
  - systemctl restart systemd-networkd sshd
EOF

  lifecycle {
    ignore_changes = [user_data, image_id, key_pair]
  }

  # This is to ensure SSH comes up
  provisioner "remote-exec" {
    inline = ["echo 'ssh up'"]

    connection {
      type         = "ssh"
      host         = self.access_ip_v4
      user         = var.ssh_user
      agent        = true
      bastion_host = var.bastion_host
      bastion_user = var.bastion_user
    }
  }
}
