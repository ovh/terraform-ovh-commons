provider "ovh" {
  #  version  = "~> 0.3"
  endpoint = "ovh-eu"
}

provider "openstack" {
  version = "= 1.5"
  region  = "${var.region_a}"
  alias   = "region_a"
}

provider "openstack" {
  version = "= 1.5"
  region  = "${var.region_b}"

  alias = "region_b"
}

provider "grafana" {
  url  = "https://grafana.metrics.ovh.net"
  auth = "${var.grafana_api_token}"
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

# letsencrypt acme challenge
# Create the private key for the registration (not the certificate)
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

# Set up a registration using a private key from tls_private_key
resource "acme_registration" "reg" {
  account_key_pem = "${tls_private_key.private_key.private_key_pem}"
  email_address   = "${var.email}"
}

# Create a certificate
resource "acme_certificate" "certificate" {
  account_key_pem = "${acme_registration.reg.account_key_pem}"
  common_name     = "${var.name}.${var.zone}"

  dns_challenge {
    provider = "ovh"
  }
}

data "openstack_networking_network_v2" "public_a" {
  name     = "Ext-Net"
  provider = "openstack.region_a"
}

resource "openstack_networking_port_v2" "public_a" {
  count              = "${var.count}"
  name               = "${var.name}_a_${count.index}"
  network_id         = "${data.openstack_networking_network_v2.public_a.id}"
  admin_state_up     = "true"
  security_group_ids = ["${openstack_networking_secgroup_v2.sga.id}"]
  provider           = "openstack.region_a"
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

  security_group_ids = ["${openstack_networking_secgroup_v2.sgb.id}"]

  provider = "openstack.region_b"
}

data "http" "myip" {
  url = "https://api.ipify.org"
}

resource "openstack_networking_secgroup_v2" "sga" {
  name     = "${var.name}"
  provider = "openstack.region_a"
}

resource "openstack_networking_secgroup_rule_v2" "in80_a" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "0.0.0.0/0"
  port_range_min    = 80
  port_range_max    = 80
  security_group_id = "${openstack_networking_secgroup_v2.sga.id}"
  provider          = "openstack.region_a"
}

resource "openstack_networking_secgroup_rule_v2" "in443_a" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "0.0.0.0/0"
  port_range_min    = 443
  port_range_max    = 443
  security_group_id = "${openstack_networking_secgroup_v2.sga.id}"
  provider          = "openstack.region_a"
}

resource "openstack_networking_secgroup_rule_v2" "inssh_a" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "${format("%s/32", data.http.myip.body)}"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = "${openstack_networking_secgroup_v2.sga.id}"
  provider          = "openstack.region_a"
}

resource "openstack_networking_secgroup_v2" "sgb" {
  name     = "${var.name}"
  provider = "openstack.region_b"
}

resource "openstack_networking_secgroup_rule_v2" "in80_b" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "0.0.0.0/0"
  port_range_min    = 80
  port_range_max    = 80
  security_group_id = "${openstack_networking_secgroup_v2.sgb.id}"
  provider          = "openstack.region_b"
}

resource "openstack_networking_secgroup_rule_v2" "in443_b" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "0.0.0.0/0"
  port_range_min    = 443
  port_range_max    = 443
  security_group_id = "${openstack_networking_secgroup_v2.sgb.id}"
  provider          = "openstack.region_b"
}

resource "openstack_networking_secgroup_rule_v2" "inssh_b" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "${format("%s/32", data.http.myip.body)}"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = "${openstack_networking_secgroup_v2.sgb.id}"
  provider          = "openstack.region_b"
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
echo "deb http://last.public.ovh.metrics.snap.mirrors.ovh.net/ubuntu bionic main" >> /etc/apt/sources.list.d/rtm.list
echo "deb http://last.public.ovh.rtm.snap.mirrors.ovh.net/ubuntu bionic main" >> /etc/apt/sources.list.d/rtm.list

curl https://last-public-ovh-rtm.snap.mirrors.ovh.net/ovh_rtm.pub | apt-key add -
curl http://last.public.ovh.metrics.snap.mirrors.ovh.net/pub.key | apt-key add -
export DEBIAN_FRONTEND=noninteractive
apt update -y && apt install -y ufw apache2 ovh-rtm-metrics-toolkit

# setup firewall
ufw default deny
ufw allow in on ens3 proto tcp from 0.0.0.0/0 to 0.0.0.0/0 port 80
ufw allow in on ens3 proto tcp from 0.0.0.0/0 to 0.0.0.0/0 port 443
ufw allow in on ens3 proto tcp from ${trimspace(data.http.myip.body)}/32 to 0.0.0.0/0 port 22
ufw enable

# setup apache2
cp /tmp/setup/www.conf /etc/apache2/sites-available/
cp /tmp/setup/ports.conf /etc/apache2
a2enmod ssl
a2enmod rewrite
a2ensite www
a2dissite 000-default

# setup systemd services
systemctl enable apache2 ufw beamium
systemctl restart apache2 ufw beamium
SETUP
}

data "template_file" "www_conf" {
  count    = 2
  template = "${file("${path.module}/www.conf.tpl")}"

  vars {
    server_name = "${var.name}.${var.zone}"
    dc          = "${count.index == 0 ? "gravelines" : "strasbourg"}"
  }
}

data "template_file" "userdata" {
  count = 2

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
  - path: /tmp/setup/www.conf
    permissions: '0644'
    content: |
      ${indent(6, element(data.template_file.www_conf.*.rendered, count.index))}
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
  user_data   = "${element(data.template_file.userdata.*.rendered, count.index)}"

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
  user_data   = "${element(data.template_file.userdata.*.rendered, count.index+1)}"

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

  provisioner "remote-exec" {
    inline = ["rm -Rf /home/ubuntu/www/*", "mkdir -p /home/ubuntu/www"]
  }

  provisioner "file" {
    source      = "./www/"
    destination = "/home/ubuntu/www"
  }

  provisioner "remote-exec" {
    inline = ["mv /home/ubuntu/www/index-gravelines.html /home/ubuntu/www/index.html"]
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

  provisioner "remote-exec" {
    inline = ["rm -Rf /home/ubuntu/www/*", "mkdir -p /home/ubuntu/www"]
  }

  provisioner "file" {
    source      = "./www/"
    destination = "/home/ubuntu/www/"
  }

  provisioner "remote-exec" {
    inline = ["mv /home/ubuntu/www/index-strasbourg.html /home/ubuntu/www/index.html"]
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

data "template_file" "ipv4_addrs" {
  template = "${element(compact(split(",", replace(join(",", flatten(openstack_networking_port_v2.public_b.*.all_fixed_ips)), "/[[:alnum:]]+:[^,]+/", ""))), count.index)}"
}

data "ovh_iploadbalancing" "iplb" {
  service_name = "${var.iplb}"
}

resource "ovh_domain_zone_record" "subdomain_record" {
  zone      = "${data.ovh_domain_zone.rootzone.name}"
  subdomain = "${var.name}"
  fieldtype = "A"
  target    = "${data.ovh_iploadbalancing.iplb.ipv4}"
}

resource "ovh_iploadbalancing_tcp_frontend" "front80" {
  service_name    = "${data.ovh_iploadbalancing.iplb.service_name}"
  display_name    = "${var.name}_80"
  zone            = "all"
  port            = "80"
  default_farm_id = "${ovh_iploadbalancing_tcp_farm.farm80.id}"
}

resource "ovh_iploadbalancing_tcp_farm" "farm80" {
  service_name = "${data.ovh_iploadbalancing.iplb.service_name}"
  display_name = "${var.name}_80"
  zone         = "all"

  probe {
    port     = 80
    interval = 30
    type     = "tcp"
  }
}

resource "ovh_iploadbalancing_tcp_farm_server" "iplb80a" {
  count        = "${var.count}"
  service_name = "${data.ovh_iploadbalancing.iplb.service_name}"
  farm_id      = "${ovh_iploadbalancing_tcp_farm.farm80.id}"
  address      = "${data.template_file.ipv4_addr_a.*.rendered[count.index]}"
  status       = "active"
  probe        = true
  port         = 80
}

resource "ovh_iploadbalancing_tcp_farm_server" "iplb80b" {
  count        = "${var.count}"
  service_name = "${data.ovh_iploadbalancing.iplb.service_name}"
  farm_id      = "${ovh_iploadbalancing_tcp_farm.farm80.id}"
  address      = "${data.template_file.ipv4_addr_b.*.rendered[count.index]}"
  status       = "active"
  probe        = true
  port         = 80
}

resource "ovh_iploadbalancing_tcp_frontend" "front443" {
  service_name    = "${data.ovh_iploadbalancing.iplb.service_name}"
  display_name    = "${var.name}_443"
  zone            = "all"
  port            = "443"
  default_farm_id = "${ovh_iploadbalancing_tcp_farm.farm443.id}"
}

resource "ovh_iploadbalancing_tcp_farm" "farm443" {
  service_name = "${data.ovh_iploadbalancing.iplb.service_name}"
  display_name = "${var.name}_443"
  zone         = "all"
  balance      = "roundrobin"

  probe {
    port     = 443
    interval = 30
    type     = "tcp"
  }
}

resource "ovh_iploadbalancing_tcp_farm_server" "iplb443a" {
  count        = "${var.count}"
  service_name = "${data.ovh_iploadbalancing.iplb.service_name}"
  farm_id      = "${ovh_iploadbalancing_tcp_farm.farm443.id}"
  address      = "${data.template_file.ipv4_addr_a.*.rendered[count.index]}"
  status       = "active"
  probe        = true
  port         = 443
}

resource "ovh_iploadbalancing_tcp_farm_server" "iplb443b" {
  count        = "${var.count}"
  service_name = "${data.ovh_iploadbalancing.iplb.service_name}"
  farm_id      = "${ovh_iploadbalancing_tcp_farm.farm443.id}"
  address      = "${data.template_file.ipv4_addr_b.*.rendered[count.index]}"
  status       = "active"
  probe        = true
  port         = 443
}

resource "ovh_iploadbalancing_refresh" "mylb" {
  service_name = "${data.ovh_iploadbalancing.iplb.id}"

  keepers = [
    "${ovh_iploadbalancing_tcp_frontend.front80.*.id}",
    "${ovh_iploadbalancing_tcp_frontend.front443.*.id}",
    "${ovh_iploadbalancing_tcp_farm.farm80.*.id}",
    "${ovh_iploadbalancing_tcp_farm.farm443.*.id}",
    "${ovh_iploadbalancing_tcp_farm_server.iplb80a.*.id}",
    "${ovh_iploadbalancing_tcp_farm_server.iplb80b.*.id}",
    "${ovh_iploadbalancing_tcp_farm_server.iplb443a.*.id}",
    "${ovh_iploadbalancing_tcp_farm_server.iplb443b.*.id}",
  ]
}

resource "grafana_data_source" "insight" {
  type                = "prometheus"
  name                = "prometheus-insight"
  access_mode         = "direct"
  url                 = "https://prometheus.insight.eu.metrics.ovh.net"
  username            = "token"
  password            = "dummy"
  basic_auth_enabled  = true
  basic_auth_username = "token"
  basic_auth_password = "${var.metrics_insight_token}"
}

data "template_file" "dashboardjson" {
  template = "${file("${path.module}/dashboard.json.tpl")}"

  vars {
    name       = "${var.name}"
    datasource = "${grafana_data_source.insight.name}"
  }
}

resource "grafana_dashboard" "metrics" {
  config_json = "${data.template_file.dashboardjson.rendered}"
}
