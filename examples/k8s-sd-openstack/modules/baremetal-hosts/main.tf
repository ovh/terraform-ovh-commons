resource "ovh_me_installation_template" "ubuntu" {
  base_template_name = var.base_template_name
  template_name      = "${var.base_template_name}-${var.name}"
  default_language   = "en"

  customization {
    change_log   = "v1"
    ssh_key_name = var.keypair
  }
}

data ovh_dedicated_server_boots "harddisk" {
  for_each = var.hosts

  service_name = each.key
  boot_type    = "harddisk"
}

data ovh_dedicated_server "server" {
  for_each     = var.hosts
  service_name = each.key
}

data openstack_networking_subnet_v2 "os_subnet" {
  subnet_id = var.os_subnet_id
}

# a mix is done with openstack world so the baremetal host can
# retrieve a IP through the Openstack metadata agent
resource openstack_networking_port_v2 "vrack" {
  for_each = var.hosts

  name           = "${var.name}_${each.value}"
  network_id     = data.openstack_networking_subnet_v2.os_subnet.network_id
  admin_state_up = "true"
  mac_address    = [for i in data.ovh_dedicated_server.server[each.key].vnis : i.nics[0] if i.mode == "vrack"][0]

  fixed_ip {
    subnet_id = data.openstack_networking_subnet_v2.os_subnet.id
  }
}

resource ovh_dedicated_server_update "server" {
  for_each = var.hosts

  service_name = data.ovh_dedicated_server.server[each.key].service_name
  boot_id      = data.ovh_dedicated_server_boots.harddisk[each.key].result[0]
  monitoring   = true
  state        = "ok"
}


resource ovh_dedicated_server_install_task "server_install" {
  for_each = var.hosts

  service_name  = data.ovh_dedicated_server.server[each.key].service_name
  template_name = ovh_me_installation_template.ubuntu.template_name

  details {
    custom_hostname = each.value
  }
}

# post provisionning is done on a null_resource
# so that it can be tainted without relaunching an install tasl
resource null_resource "post_provisionning" {
  for_each = var.hosts

  triggers = {
    install_id = ovh_dedicated_server_install_task.server_install[each.key].id
  }

  provisioner "file" {
    destination = "/tmp/eno4.network"
    content = <<EOF
[Match]
Name=eno4
[Network]
DHCP=ipv4
VLAN=eno4.vlan
EOF

    connection {
      type         = "ssh"
      user         = "root"
      host         = data.ovh_dedicated_server.server[each.key].ip
      agent        = true
      bastion_host = var.bastion_host
      bastion_user = var.bastion_user
    }
  }

  provisioner "file" {
    destination = "/tmp/eno4.vlan.netdev"
    content = <<EOF
[NetDev]
Name=eno4.vlan
Kind=vlan

[VLAN]
Id=${var.vlan_id}
EOF

    connection {
      type         = "ssh"
      user         = "root"
      host         = data.ovh_dedicated_server.server[each.key].ip
      agent        = true
      bastion_host = var.bastion_host
      bastion_user = var.bastion_user
    }
  }

  provisioner "file" {
    destination = "/tmp/eno4.vlan.network"
    content = <<EOF
[Match]
Name=eno4.vlan
[Network]
DHCP=ipv4
EOF

    connection {
      type         = "ssh"
      user         = "root"
      host         = data.ovh_dedicated_server.server[each.key].ip
      agent        = true
      bastion_host = var.bastion_host
      bastion_user = var.bastion_user
    }
  }

  # This is to ensure SSH comes up and setups eno4 net if
  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/eno4.* /etc/systemd/network/",
      "sudo systemctl restart systemd-networkd"
    ]

    connection {
      type         = "ssh"
      user         = "root"
      host         = data.ovh_dedicated_server.server[each.key].ip
      agent        = true
      bastion_host = var.bastion_host
      bastion_user = var.bastion_user
    }
  }
}
