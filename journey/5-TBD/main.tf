## DEFINE PROVIDERS
provider "ovh" {
  #  version  = "~> 0.3"
  endpoint = "ovh-eu"
}

resource "ovh_cloud_user" "openstack" {
  project_id  = "${var.project_id}"
  description = "The openstack user used to bootstrap openstack on openstack"
}

resource "ovh_cloud_network_private" "public" {
  project_id = "${var.project_id}"
  name       = "${var.name}_public"
  regions    = ["${var.region_a}", "${var.region_b}"]
  vlan_id    = 0
}

resource "ovh_cloud_network_private" "admin" {
  project_id = "${var.project_id}"
  name       = "${var.name}_admin"
  regions    = ["${var.region_a}", "${var.region_b}"]
  vlan_id    = "${var.admin_network_vlan_id}"
}

provider "openstack" {
  version     = "~> 1.2"
  region      = "${var.region_a}"

  alias = "region_a"
}

provider "openstack" {
  version     = "~> 1.2"
  region      = "${var.region_b}"

  alias = "region_b"
}

# get NATed IP to allow ssh only from terraform host
data "http" "myip" {
  url = "https://api.ipify.org"
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

module "ports_a" {
  source                   = "./modules/network_ports"
  name                     = "${var.name}"
  count                    = "${var.count}"
  remote_ip_prefix         = "${trimspace(data.http.myip.body)}/32"
  public_network_name      = "${ovh_cloud_network_private.public.name}"
  public_cidr              = "${var.public_cidr}"
  public_gateway           = "${var.public_gateway}"
  public_subnet_pool_start = "${cidrhost(cidrsubnet(var.public_cidr,1,0), 1)}"
  public_subnet_pool_end   = "${cidrhost(cidrsubnet(var.public_cidr,1,0), -2)}"
  admin_network_name       = "${ovh_cloud_network_private.admin.name}"
  admin_cidr               = "${var.admin_cidr}"
  admin_subnet_pool_start  = "${cidrhost(cidrsubnet(var.admin_cidr,1,0), 1)}"
  admin_subnet_pool_end    = "${cidrhost(cidrsubnet(var.admin_cidr,1,0), -2)}"

  providers = {
    openstack = "openstack.region_a"
  }
}

module "node_region_a" {
  source                = "./modules/node"
  name                  = "${var.name}"
  count                 = "${var.count}"
  flavor_name           = "${var.flavor_name}"
  ssh_public_key        = "${var.ssh_public_key}"
  remote_ip_prefix      = "${trimspace(data.http.myip.body)}/32"
  fqdn                  = "${var.name}.${var.zone}"
  public_gateway        = "${var.public_gateway}"
  public_port_ids       = "${module.ports_a.public_port_ids}"
  private_port_ids      = "${module.ports_a.admin_port_ids}"
  public_ipv4s          = "${module.ports_a.public_port_ipv4s}"
  private_ipv4s         = "${module.ports_a.admin_port_ipv4s}"
  backup_public_ipv4s   = "${module.ports_b.public_port_ipv4s}"
  backup_private_ipv4s  = "${module.ports_b.admin_port_ipv4s}"
  tls_private_key_pem   = "${acme_certificate.certificate.private_key_pem}"
  tls_certificate_pem   = "${acme_certificate.certificate.certificate_pem}"
  tls_issuer_pem        = "${acme_certificate.certificate.issuer_pem}"
  vrrp_password         = "${var.vrrp_password}"
  vrrp_router_id        = "1"
  vrrp_backup_router_id = "2"

  providers = {
    openstack = "openstack.region_a"
  }
}

module "ports_b" {
  source                   = "./modules/network_ports"
  name                     = "${var.name}"
  count                    = "${var.count}"
  remote_ip_prefix         = "${trimspace(data.http.myip.body)}/32"
  public_network_name      = "${ovh_cloud_network_private.public.name}"
  public_cidr              = "${var.public_cidr}"
  public_gateway           = "${var.public_gateway}"
  public_subnet_pool_start = "${cidrhost(cidrsubnet(var.public_cidr,1,0), 1)}"
  public_subnet_pool_end   = "${cidrhost(cidrsubnet(var.public_cidr,1,0), -2)}"
  admin_network_name       = "${ovh_cloud_network_private.admin.name}"
  admin_cidr               = "${var.admin_cidr}"
  admin_subnet_pool_start  = "${cidrhost(cidrsubnet(var.admin_cidr,1,0), 1)}"
  admin_subnet_pool_end    = "${cidrhost(cidrsubnet(var.admin_cidr,1,0), -2)}"

  providers = {
    openstack = "openstack.region_b"
  }
}

module "node_region_b" {
  source                = "./modules/node"
  name                  = "${var.name}"
  count                 = "${var.count}"
  flavor_name           = "${var.flavor_name}"
  ssh_public_key        = "${var.ssh_public_key}"
  remote_ip_prefix      = "${trimspace(data.http.myip.body)}/32"
  fqdn                  = "${var.name}.${var.zone}"
  public_gateway        = "${var.public_gateway}"
  public_port_ids       = "${module.ports_b.public_port_ids}"
  private_port_ids      = "${module.ports_b.admin_port_ids}"
  public_ipv4s          = "${module.ports_b.public_port_ipv4s}"
  private_ipv4s         = "${module.ports_b.admin_port_ipv4s}"
  backup_public_ipv4s   = "${module.ports_a.public_port_ipv4s}"
  backup_private_ipv4s  = "${module.ports_a.admin_port_ipv4s}"
  tls_private_key_pem   = "${acme_certificate.certificate.private_key_pem}"
  tls_certificate_pem   = "${acme_certificate.certificate.certificate_pem}"
  tls_issuer_pem        = "${acme_certificate.certificate.issuer_pem}"
  vrrp_password         = "${var.vrrp_password}"
  vrrp_router_id        = "2"
  vrrp_backup_router_id = "1"

  providers = {
    openstack = "openstack.region_b"
  }
}

resource "null_resource" "site_example" {
  provisioner "local-exec" {
    command = <<EOF
rm -Rf site
hugo new site site
(cd site/themes && wget https://github.com/matcornic/hugo-theme-learn/archive/master.zip && unzip master.zip && rm master.zip)
cat | tee -a site/config.toml <<CONFIG
theme = "hugo-theme-learn-master"
[outputs]
home = [ "HTML", "RSS", "JSON"]
CONFIG
(cd site && hugo new --kind chapter basics/hola.md)
(cd site && hugo)
EOF
  }
}

resource "null_resource" "provision_a" {
  count = "${var.count}"

  triggers {
    id = "${module.node_region_a.instance_ids[count.index]}"
  }

  connection {
    host = "${module.ports_a.public_port_ipv4s[count.index]}"
    user = "ubuntu"
  }

  provisioner "file" {
    source      = "./site/public"
    destination = "/home/ubuntu/${var.name}"
  }
}

resource "null_resource" "provision_b" {
  count = "${var.count}"

  triggers {
    id = "${module.node_region_b.instance_ids[count.index]}"
  }

  connection {
    host = "${module.ports_b.public_port_ipv4s[count.index]}"
    user = "ubuntu"
  }

  provisioner "file" {
    source      = "./site/public"
    destination = "/home/ubuntu/${var.name}"
  }
}


# setup subdomain
data "ovh_domain_zone" "rootzone" {
  name = "${var.zone}"
}

resource "ovh_domain_zone_record" "subdomain_records_a" {
  count     = "${var.count}"
  zone      = "${data.ovh_domain_zone.rootzone.name}"
  subdomain = "${var.name}"
  fieldtype = "A"
  target    = "${element(module.ports_a.public_port_ipv4s, count.index)}"
}

resource "ovh_domain_zone_record" "subdomain_records_b" {
  count     = "${var.count}"
  zone      = "${data.ovh_domain_zone.rootzone.name}"
  subdomain = "${var.name}"
  fieldtype = "A"
  target    = "${element(module.ports_b.public_port_ipv4s, count.index)}"
}
