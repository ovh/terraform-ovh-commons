resource "openstack_compute_keypair_v2" "keypair" {
  name       = "${var.name}"
  public_key = "${file(var.ssh_public_key)}"
}

data "template_file" "keepalived" {
  count    = "${var.count}"
  template = "${file("${path.module}/keepalived.conf.tpl")}"

  vars {
    virtual_ip_master = "${element(var.public_ipv4s, count.index)}"
    virtual_ip_backup = "${element(var.backup_public_ipv4s, count.index)}"

    # vrid are comprised between 1 and 255
    virtual_router_id_master = "${var.vrrp_router_id}"
    virtual_router_id_backup = "${var.vrrp_backup_router_id}"
    private_ip               = "${element(var.private_ipv4s, count.index)}"
    private_peer_ip          = "${element(var.backup_private_ipv4s, count.index)}"
    auth_password            = "${var.vrrp_password}"
    gateway                  = "${var.public_gateway}"
  }
}

data "template_file" "myblog_conf" {
  count    = "${var.count}"
  template = "${file("${path.module}/myblog.conf.tpl")}"

  vars {
    private_ip  = "${element(var.private_ipv4s, count.index)}"
    server_name = "${var.fqdn}"
  }
}

data "template_file" "haproxy_backends" {
  count    = "${var.count}"
  template = "server back${count.index} ${var.private_ipv4s[count.index]}:443 maxconn 5000"
}

data "template_file" "haproxy_reload" {
  count    = "${var.count}"
  template = "${file("${path.module}/haproxy_reload.sh")}"

  vars {
    virtual_ip_master = "${element(var.public_ipv4s, count.index)}"
    virtual_ip_backup = "${element(var.backup_public_ipv4s, count.index)}"
    private_backends  = "${indent(6, join("\n", data.template_file.haproxy_backends.*.rendered))}"
  }
}

data "template_file" "setup" {
  template = <<SETUP
#!/bin/bash
#first setup tmp network access to internet
dhclient ens4

# install softwares & depencencies
apt update -y && apt install -y keepalived haproxy ufw apache2

# ensure all services are stopped to prepare setup
systemctl stop apache2 keepalived haproxy

# setup firewall
ufw default deny
ufw allow in on ens4 proto tcp from 0.0.0.0/0 to 0.0.0.0/0 port 80
ufw allow in on ens4 proto tcp from 0.0.0.0/0 to 0.0.0.0/0 port 443
ufw allow in on ens4 proto tcp from ${var.remote_ip_prefix} to 0.0.0.0/0 port 22
ufw allow in on ens3 from 10.0.0.0/16
ufw enable

# setup keepalived
cp /tmp/setup/keepalived.conf /etc/keepalived
cp /tmp/setup/haproxy_reload.sh /etc/keepalived

# setup haproxy
groupadd haproxy
useradd haproxy -g haproxy -M -r -s /usr/bin/nologin
mkdir -p /run/haproxy
chown -R haproxy:haproxy /run/haproxy

# setup apache2
cp /tmp/setup/myblog.conf /etc/apache2/sites-available/
cp /tmp/setup/ports.conf /etc/apache2
a2enmod ssl
a2ensite myblog
a2dissite 000-default

# setup systemd services
systemctl disable haproxy
systemctl enable keepalived apache2 ufw
systemctl start keepalived apache2 ufw
SETUP
}

data "template_file" "userdata" {
  count = "${var.count}"

  template = <<CLOUDCONFIG
#cloud-config

write_files:
  - path: /etc/letsencrypt/cert.pem
    permissions: '0600'
    content: |
      ${indent(6, var.tls_certificate_pem)}
  - path: /etc/letsencrypt/key.pem
    permissions: '0600'
    content: |
      ${indent(6, var.tls_private_key_pem)}
  - path: /etc/letsencrypt/issuer.pem
    permissions: '0600'
    content: |
      ${indent(6, var.tls_issuer_pem)}
  - path: /tmp/setup/run.sh
    permissions: '0755'
    content: |
      ${indent(6, data.template_file.setup.rendered)}
  - path: /tmp/setup/keepalived.conf
    permissions: '0644'
    content: |
      ${indent(6, element(data.template_file.keepalived.*.rendered, count.index))}
  - path: /tmp/setup/haproxy_reload.sh
    permissions: '0755'
    content: |
      ${indent(6, element(data.template_file.haproxy_reload.*.rendered, count.index))}
  - path: /tmp/setup/myblog.conf
    permissions: '0644'
    content: |
      ${indent(6, element(data.template_file.myblog_conf.*.rendered, count.index))}
  - path: /tmp/setup/ports.conf
    permissions: '0644'
    content: |
      # If you just change the port or add more ports here, you will likely also
      # have to change the VirtualHost statement in
      # /etc/apache2/sites-enabled/000-default.conf
      #Listen 80
      <IfModule ssl_module>
           Listen ${element(var.private_ipv4s, count.index)}:443
      </IfModule>
      <IfModule mod_gnutls.c>
           Listen ${element(var.private_ipv4s, count.index)}:443
      </IfModule>
      # vim: syntax=apache ts=4 sw=4 sts=4 sr noet

  - path: /etc/systemd/network/30-ens3.network
    permissions: '0644'
    content: |
      [Match]
      Name=ens3
      [Network]
      DHCP=no
      Address=${element(var.private_ipv4s, count.index)}
  - path: /etc/systemd/network/40-ens4.network
    permissions: '0644'
    content: |
      [Match]
      Name=ens4
      [Network]
      DHCP=no

runcmd:
   - /tmp/setup/run.sh
CLOUDCONFIG
}

resource "openstack_compute_instance_v2" "node" {
  count       = "${var.count}"
  name        = "${var.name}"
  image_name  = "Ubuntu 18.04"
  flavor_name = "${var.flavor_name}"
  key_pair    = "${openstack_compute_keypair_v2.keypair.name}"
  user_data   = "${data.template_file.userdata.*.rendered[count.index]}"

  network {
    port = "${var.private_port_ids[count.index]}"
  }

  network {
    access_network = true
    port           = "${var.public_port_ids[count.index]}"
  }
}
