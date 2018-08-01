- [Objective](#sec-1)
- [Pre-requisites](#sec-2)
- [In practice](#sec-4)
- [Going Further](#sec-5)


# Objective<a id="sec-1" name="sec-1"></a>

This document is the fourth part of a [step by step guide](../0-simple-terraform/README.md) on how to use 
the [Hashicorp Terraform](https://terraform.io) tool with [OVH Public Cloud](https://www.ovh.com/world/public-cloud/instances/). 
Previously we created a Public Cloud instance to host a static blog based on [hugo](https://gohugo.io/getting-started/quick-start/) working with post-boot scripts.
Now we'll go a bit further adding TLS security and redundency across regions using Roud Robin DNS. We'll start our first high availability infrastructure. For that, we'll see:
- how to generate a TLS certificate with terraform
- how to manage two instances in two regions
- how to live manage the DNS using the OVH provider in terraform in order to round robin DNS across regions.

Every documented part here should be considered as an addition of the previous steps.

# Pre-requisites<a id="sec-2" name="sec-2"></a>

Please refer to the pre-requisites paragraph of the [first part](../0-simple-terraform/README.md) of this guide.

In addition of the previous pre-requisites, we need to introduce the ACME Let's Encrypt provider to manage the TLS certificate. The ACME provider is not already merged in the upstream terraform code, so you have to install it as a side plugin.

## Installing the ACME terraform module

Installing a plugin for terraform is really simple:

```bash
mkdir -p ~/.terraform.d/plugins
curl -Lo /tmp/terraform-provider-acme.zip \
 https://github.com/vancluever/terraform-provider-acme/releases/download/v1.0.0/terraform-provider-acme_v1.0.0_linux_amd64.zip
unzip  /tmp/terraform-provider-acme.zip -d /tmp
mv /tmp/terraform-provider-acme ~/.terraform.d/plugins
```

# In practice<a id="sec-4" name="sec-4"></a>

## Generating the TLS certificate

To do that, we need a key to register on Let's Encrypt API and to sign our request.

```terraform
provider "acme" {
  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
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
```

Let's Encrypt need to certify you are the owner of the domain. For that, they challenge you asking for some modifications on the space served by the webserver by adding a special file there. As the server does not exist yet, we'll use the second challenge method which is DNS. Let's Encrypt will ask us to ass a TXT entry in the DNS zone to certify we own it.

## Adapting the 1rst instance to use the certificate

Of course, we have to adapt a little bit the post install scripts to install and use the TLS certificate. Here are the changes required in the 1rst instance to configure the certificate.

Firstly, the user-data should be modified:

```terraform
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
```

The template for the virtual host in Apache needs some changes too in order to use the .pem files. Remember, it was managed by a local template file "myblog.conf.tpl"

```apache
<IfModule mod_ssl.c>
      <VirtualHost 0.0.0.0:80>
         RewriteEngine On
         RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
      </VirtualHost>

      <VirtualHost 0.0.0.0:443>
              ServerName ${server_name}
              DocumentRoot /home/ubuntu/myblog

              <Directory /home/ubuntu/myblog>
                  Options FollowSymLinks
                  AllowOverride Limit Options FileInfo
                  DirectoryIndex index.html
                  Require all granted
              </Directory>

              ErrorLog $$$${APACHE_LOG_DIR}/error.log
              CustomLog $$$${APACHE_LOG_DIR}/access.log combined

              SSLEngine on
              SSLCertificateFile /etc/letsencrypt/cert.pem
              SSLCertificateKeyFile /etc/letsencrypt/key.pem
              SSLCertificateChainFile /etc/letsencrypt/issuer.pem
      </VirtualHost>
</IfModule>
```

Now we have a single instance working with a TLS certificate. Let's do the same for a second instance in another region.

## Adding the B region with the B instance

We'll start by adding a new OpenStack provider targeting a new region in 'main.tf'

```terraform
provider "openstack" {
  version     = "= 1.5"
  region      = "${var.region_b}"

  alias = "region_b"
}
```

Now, for every action specific to the A instance, we'll do the same for the B instance. 

Remark: A and B instance can share the same template files. There is no need to create B template files.

```terraform
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

resource "openstack_compute_keypair_v2" "keypair_b" {
  name       = "${var.name}"
  public_key = "${file(var.ssh_public_key)}"
  provider   = "openstack.region_b"
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
```

Now we have 2 instances. We need to setup the Round Robin DNS.

## Adding the OVH provider and configure the DNS zone

Let's edit 'main.tf' to add the OVH provider we'll use for the DNS part.

Now we want to declare the OVH provider.

```terraform
provider "ovh" {
  #  version  = "~> 0.3"
  endpoint = "ovh-eu"
}
```

To set your OVH API credentials, please refer to the [documentation](https://www.terraform.io/docs/providers/ovh/index.html#configuration-reference).

```terraform
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
```

Now we need few more variables in 'variables.tf'

```terraform
variable "region_b" {
  description = "The id of the second openstack region"
  default = "WAW1"
}

variable "zone" {
  description = "the domain root zone"
}

variable "email" {
  description = "email for letsencrypt registration"
}
```

## Run Terraform

Now we can apply those changes. Terraform will generate the certificate, delete the A instance because his configuration has changed and recreate it as well as the B instance. Then the DNS will be updated to manage the Round Robin DNS.

```bash
$ eval $(ssh-agent)
$ ssh-add
$ terraform apply -auto-approve -var zone=iac.ovh
```

# Going Further<a id="sec-5" name="sec-5"></a>

We're finished with the terraform first high availability architecture on OVH. Round Robin DNS is not a production ready solution, we'll see how to improve it for a rock-solid solution with a load balancing system.

See you on [the fifth step](../WIP/README.md) of our journey.
