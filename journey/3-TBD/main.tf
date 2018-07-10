
terraform {
  backend "swift" {
    container = "demo-remote-state"
  }
}

provider "ovh" {
  #  version  = "~> 0.3"
  endpoint = "ovh-eu"
}

provider "openstack" {
  version     = "= 1.5"
  region      = "${var.region_a}"
  alias = "region_a"
}

provider "openstack" {
  version     = "= 1.5"
  region      = "${var.region_b}"

  alias = "region_b"
}

# letsencrypt acme challenge
# Create the private key for the registration (not the certificate)
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

# Set up a registration using a private key from tls_private_key
resource "acme_registration" "reg" {
  server_url      = "https://acme-v01.api.letsencrypt.org/directory"
  account_key_pem = "${tls_private_key.private_key.private_key_pem}"
  email_address   = "${var.email}"
}

# Create a certificate
resource "acme_certificate" "certificate" {
  server_url      = "https://acme-v01.api.letsencrypt.org/directory"
  account_key_pem = "${tls_private_key.private_key.private_key_pem}"
  common_name     = "${var.name}.${var.zone}"

  dns_challenge {
    provider = "ovh"
  }

  registration_url = "${acme_registration.reg.id}"
}

data "openstack_networking_network_v2" "public_a" {
  name     = "Ext-Net"
  provider = "openstack.region_a"
}

resource "openstack_networking_port_v2" "public_a" {
  count          = "${var.count}"
  name           = "${var.name}_a_${count.index}"
  network_id     = "${data.openstack_networking_network_v2.public_a.id}"
  admin_state_up = "true"
  provider       = "openstack.region_a"
}

data "openstack_networking_network_v2" "public_b" {
  name     = "Ext-Net"
  provider = "openstack.region_b"
}

resource "openstack_networking_port_v2" "public_b" {
  count          = "${var.count}"
  name           = "${var.name}_b_${count.index}"
  network_id     = "${data.openstack_networking_network_v2.public_b.id}"
  admin_state_up = "true"
  provider       = "openstack.region_b"
}

data "http" "myip" {
  url = "https://api.ipify.org"
}

resource "openstack_compute_keypair_v2" "keypair_a" {
  name       = "${var.name}"
  public_key = "${file(var.ssh_public_key)}"
  provider   = "openstack.region_a"
}

resource "openstack_compute_keypair_v2" "keypair_b" {
  name       = "${var.name}"
  public_key = "${file(var.ssh_public_key)}"
  provider   = "openstack.region_b"
}

data "template_file" "setup" {
  template = <<SETUP
#!/bin/bash

# install softwares & depencencies
apt update -y && apt install -y ufw apache2

# setup firewall
ufw default deny
ufw allow in on ens3 proto tcp from 0.0.0.0/0 to 0.0.0.0/0 port 80
ufw allow in on ens3 proto tcp from 0.0.0.0/0 to 0.0.0.0/0 port 443
ufw allow in on ens3 proto tcp from ${trimspace(data.http.myip.body)}/32 to 0.0.0.0/0 port 22
ufw enable

# setup apache2
cp /tmp/setup/myblog.conf /etc/apache2/sites-available/
cp /tmp/setup/ports.conf /etc/apache2
a2enmod ssl
a2enmod rewrite
a2ensite myblog
a2dissite 000-default

# setup systemd services
systemctl enable apache2 ufw
systemctl restart apache2 ufw
SETUP
}

data "template_file" "myblog_conf" {
  template = "${file("${path.module}/myblog.conf.tpl")}"

  vars {
    server_name = "${var.name}.${var.zone}"
  }
}

data "template_file" "userdata" {
  template = <<CLOUDCONFIG
#cloud-config

write_files:
  - path: /etc/letsencrypt/cert.pem
    permissions: '0600'
    content: |
      ${indent(6, acme_certificate.certificate.certificate_pem)}
  - path: /etc/letsencrypt/key.pem
    permissions: '0600'
    content: |
      ${indent(6, acme_certificate.certificate.private_key_pem)}
  - path: /etc/letsencrypt/issuer.pem
    permissions: '0600'
    content: |
      ${indent(6, acme_certificate.certificate.issuer_pem)}
  - path: /tmp/setup/run.sh
    permissions: '0755'
    content: |
      ${indent(6, data.template_file.setup.rendered)}
  - path: /tmp/setup/myblog.conf
    permissions: '0644'
    content: |
      ${indent(6, data.template_file.myblog_conf.rendered)}
  - path: /tmp/setup/ports.conf
    permissions: '0644'
    content: |
      # If you just change the port or add more ports here, you will likely also
      # have to change the VirtualHost statement in
      # /etc/apache2/sites-enabled/000-default.conf
      Listen 80
      <IfModule ssl_module>
           Listen 0.0.0.0:443
      </IfModule>
      <IfModule mod_gnutls.c>
           Listen 0.0.0.0:443
      </IfModule>
      # vim: syntax=apache ts=4 sw=4 sts=4 sr noet

  - path: /etc/systemd/network/30-ens3.network
    permissions: '0644'
    content: |
      [Match]
      Name=ens3
      [Network]
      DHCP=ipv4

runcmd:
   - /tmp/setup/run.sh
CLOUDCONFIG
}

resource "openstack_compute_instance_v2" "nodes_a" {
  count       = "${var.count}"
  name        = "${var.name}_a_${count.index}"
  image_name  = "Ubuntu 18.04"
  flavor_name = "${var.flavor_name}"
  key_pair    = "${openstack_compute_keypair_v2.keypair_a.name}"
  user_data   = "${data.template_file.userdata.rendered}"

  network {
    access_network = true
    port           = "${openstack_networking_port_v2.public_a.*.id[count.index]}"
  }

  provider = "openstack.region_a"
}

resource "openstack_compute_instance_v2" "nodes_b" {
  count       = "${var.count}"
  name        = "${var.name}_b_${count.index}"
  image_name  = "Ubuntu 18.04"
  flavor_name = "${var.flavor_name}"
  key_pair    = "${openstack_compute_keypair_v2.keypair_b.name}"
  user_data   = "${data.template_file.userdata.rendered}"

  network {
    access_network = true
    port           = "${openstack_networking_port_v2.public_b.*.id[count.index]}"
  }
  
  provider = "openstack.region_b"
}

resource "null_resource" "provision_a" {
  count = "${var.count}"

  triggers {
    id = "${openstack_compute_instance_v2.nodes_a.*.id[count.index]}"
  }

  connection {
    host = "${openstack_compute_instance_v2.nodes_a.*.access_ip_v4[count.index]}"
    user = "ubuntu"
  }

  provisioner "file" {
    source      = "./www/public"
    destination = "/home/ubuntu/${var.name}"
  }
}

resource "null_resource" "provision_b" {
  count = "${var.count}"

  triggers {
    id = "${openstack_compute_instance_v2.nodes_b.*.id[count.index]}"
  }

  connection {
    host = "${openstack_compute_instance_v2.nodes_b.*.access_ip_v4[count.index]}"
    user = "ubuntu"
  }

  provisioner "file" {
    source      = "./www/public"
    destination = "/home/ubuntu/${var.name}"
  }
}

# setup subdomain
data "ovh_domain_zone" "rootzone" {
  name = "${var.zone}"
}

# trick to filter ipv6 addrs 
data "template_file" "ipv4_addr_a" {
  count    = "${var.count}"
  template = "${element(compact(split(",", replace(join(",", flatten(openstack_networking_port_v2.public_a.*.all_fixed_ips)), "/[[:alnum:]]+:[^,]+/", ""))), count.index)}"
}

data "template_file" "ipv4_addr_b" {
  count    = "${var.count}"
  template = "${element(compact(split(",", replace(join(",", flatten(openstack_networking_port_v2.public_b.*.all_fixed_ips)), "/[[:alnum:]]+:[^,]+/", ""))), count.index)}"
}

resource "ovh_domain_zone_record" "subdomain_records_a" {
  count     = "${var.count}"
  zone      = "${data.ovh_domain_zone.rootzone.name}"
  subdomain = "${var.name}"
  fieldtype = "A"
  target    = "${data.template_file.ipv4_addr_a.*.rendered[count.index]}"
}

resource "ovh_domain_zone_record" "subdomain_records_b" {
  count     = "${var.count}"
  zone      = "${data.ovh_domain_zone.rootzone.name}"
  subdomain = "${var.name}"
  fieldtype = "A"
  target    = "${data.template_file.ipv4_addr_b.*.rendered[count.index]}"
}
