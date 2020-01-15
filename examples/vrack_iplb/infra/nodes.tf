resource openstack_networking_port_v2 nodes_vrack {
  count          = var.nodes
  name           = "${var.name}-${count.index}"
  network_id     = data.openstack_networking_network_v2.vrack.id
  admin_state_up = "true"

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.subnet.id
  }
}

resource openstack_compute_instance_v2 nodes {
  count       = var.nodes
  name        = "${var.name}-${count.index}"
  image_name  = "Ubuntu 18.04"
  flavor_name = "s1-4"
  key_pair    = openstack_compute_keypair_v2.keypair.name

  network {
    port = openstack_networking_port_v2.nodes_vrack[count.index].id
  }

  lifecycle {
    ignore_changes = [user_data, image_name, image_id]
  }

  user_data = <<EOF
#cloud-config
write_files:
 - path: /tmp/index.html
   permissions: '0644'
   content: |
     Hello world from node ${count.index}
runcmd:
  - (cd /tmp && nohup python3 -m http.server 80 &)
  - (cd /tmp && nohup python3 -m http.server 443 &)
EOF
}
