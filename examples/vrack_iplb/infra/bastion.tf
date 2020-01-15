###
### This script setups an Openstack Instance which has the role
### of a NAT gateway & bastion host, having a NIC in the Vrack
### and on Ext-Net.
### It allows ssh traffic only from a restricted IPv4 prefix list
###

data openstack_networking_network_v2 ext_net {
  name      = "Ext-Net"
  tenant_id = ""
}

resource openstack_networking_secgroup_v2 bastion_sg {
  name        = "${var.name}_bastion"
  description = "${var.name} security group for bastion hosts"
}

resource openstack_networking_secgroup_rule_v2 bastion_in_ssh {
  count             = length(var.remote_ssh_prefixes)
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = tolist(var.remote_ssh_prefixes)[count.index]
  security_group_id = openstack_networking_secgroup_v2.bastion_sg.id
}

resource openstack_networking_port_v2 bastion_fip {
  name           = "${var.name}-bastion-pub"
  network_id     = data.openstack_networking_network_v2.ext_net.id
  admin_state_up = "true"

  security_group_ids = [
    openstack_networking_secgroup_v2.bastion_sg.id
  ]
}
resource openstack_compute_instance_v2 bastion {
  name        = "${var.name}-bastion"
  image_name  = "Ubuntu 18.04"
  flavor_name = "s1-4"
  key_pair    = openstack_compute_keypair_v2.keypair.name

  network {
    port           = openstack_networking_port_v2.bastion_fip.id
    access_network = true
  }

  network {
    port = openstack_networking_port_v2.bastion_vrack.id
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
    # the next two lines are useful if you want to use the bastion
    # as an internet gateway
    IPMasquerade=yes
    IPForward=ipv4
    [DHCP]
    # favor ens3 default routes over ens4
    RouteMetric=2048
runcmd:
  - sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin no/' /etc/ssh/sshd_config
  - systemctl restart systemd-networkd sshd
    # the next 3 lines are mandatory if you use the bastion as an internet
    # gateway, to avoid another instance fetching the bastion userdata/metadata
    # instead of its own
  - iptables -A FORWARD -s 0.0.0.0/0 -d 169.254.169.254 -j DROP
  - iptables-save --counters > /var/lib/iptables/rules-save
  - systemctl enable iptables-restore.service
EOF
}
