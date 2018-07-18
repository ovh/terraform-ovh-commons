<div id="table-of-contents">
<h2>Table of Contents</h2>
<div id="text-table-of-contents">
<ul>
<li><a href="#sec-1">1. Objective</a></li>
<li><a href="#sec-2">2. Pre requisites</a></li>
<li><a href="#sec-3">3. install custom providers</a>
<ul>
<li><a href="#sec-3-1">3.1. install acme provider</a></li>
</ul>
</li>
<li><a href="#sec-4">4. In pratice: Terraform ???</a></li>
<li><a href="#sec-5">5. Workspaces</a></li>
<li><a href="#sec-6">6. Going Further</a></li>
</ul>
</div>
</div>


# Objective<a id="sec-1" name="sec-1"></a>

This document is the third part of a [step by step guide](../0-simple-terraform/README.md) on how to use 
the [Hashicorp Terraform](https://terraform.io) tool with [OVH Cloud](https://www.ovh.com/fr/public-cloud/instances/). It will help you create 
an openstack swift container on the region of your choice, but this
time by introducing terraform state management and terraform workspaces.

# Pre requisites<a id="sec-2" name="sec-2"></a>

Please refer to the pre requisites paragraph of the [first part](../0-simple-terraform/README.md) of this guide.

Build your blog on whatever techno you like. As this is not the main purpose of 
this tutorial, we'll provide you a simple static blog content generated with 
[hugo](https://gohugo.io/getting-started/quick-start/), a popular static website generator.

First follow the getting started guide to install hugo on your system.
Then generate a website with some content

    curl -Lo /tmp/example.zip https://github.com/Xzya/hugo-material-blog/archive/master.zip
    unzip /tmp/example.zip -d /tmp
    mv /tmp/hugo-material-blog-master/exampleSite ./www
    mkdir ./www/themes
    mv /tmp/hugo-material-blog-master ./www/themes/hugo-material-blog

You can edit/remove/add some content, then generate your site 

    cd www && hugo

Your webiste has been generated in the \`www/public\` directory

NB: you can preview your site by serving files with hugo:

    hugo server -b 0.0.0.0 -p 8080 -s www

# install custom providers<a id="sec-3" name="sec-3"></a>

## Install Terraform acme provider

Each terraform provider extend the tool capabilities and there are a lot of possibilities. Here we'll add to terraform the capability to manage certificates using Let's Encrypt certificate authority. As ACME provider is not yet included in terraform upstream code (it should be in a near futur), we'll add it as a plugin.

    mkdir -p ~/.terraform.d/plugins
    curl -Lo /tmp/terraform-provider-acme.zip \
     https://github.com/vancluever/terraform-provider-acme/releases/download/v1.0.0/terraform-provider-acme_v1.0.0_linux_amd64.zip
    unzip  /tmp/terraform-provider-acme.zip -d /tmp
    mv /tmp/terraform-provider-acme ~/.terraform.d/plugins

Now we are ready to install hugo and TLS certificate in an instance. Let's do it.

# In pratice: Terraform ???<a id="sec-4" name="sec-4"></a>

Configure terraform providers and state storage

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

Vars & outputs remains just as before:

    variable "region_a" {
      description = "The id of the first openstack region"
      default = "DE1"
    }
    
    variable "region_b" {
      description = "The id of the second openstack region"
      default = "WAW1"
    }
    
    variable "name" {
      description = "name of blog. Used to forge subdomain"
      default = "myblog"
    }
    
    variable "ssh_public_key" {
      description = "The path of the ssh public key that will be used by ansible to provision the hosts"
      default     = "~/.ssh/id_rsa.pub"
    }
    
    variable "flavor_name" {
      description = "flavor name of nodes."
      default     = "s1-2"
    }
    
    variable "count" {
      description = "number of blog nodes per region"
      default     = 1
    }
    
    variable "zone" {
      description = "the domain root zone"
    }
    
    variable "email" {
      description = "email for letsencrypt registration"
    }

Generate lets encrypt certificate

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

Create the ports on Ext net to get public ips for your nodes

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

Then create the nodes:

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

Great, now upload the website contents

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

then run terraform init:

    source ~/openrc.sh
    terraform init

    Initializing the backend...
    
    Successfully configured the backend "swift"! Terraform will automatically
    use this backend unless the backend configuration changes.
    ...

Alright. Now let's apply the script as usual:

    source ~/openrc.sh
    terraform apply -auto-approve
    ...

And look at the directory structure:

    ls

    main.tf  Makefile  outputs.tf  README.org  variables.tf

No `tfstate` file! Where could it be? Well it should be present in a swift container
as defined in the `tf` file. So lets check this:

    openstack container list
    openstack object list demo-remote-state

    +-------------------------------+
    | Name                          |
    +-------------------------------+
    | demo-remote-state             |
    +-------------------------------+
    +------------+
    | Name       |
    +------------+
    | tfstate.tf |
    +------------+

Right where it should be. This means that anyone running the same script on another
machine with credentials accessing the same project on the same openstack region
should have access to this `tfstate` file.

Notice: terraform maintains a local copy of this file in the `.terraform` directory.

# Workspaces<a id="sec-5" name="sec-5"></a>

Terraform also allows you to manage your environments with the \`workspaces\` feature.
You can easily switch from one environment to the other by a simple command.

# Going Further<a id="sec-6" name="sec-6"></a>

We're finished with terraform basics on OVH. Now we'll go deeper into bootstrapping 
real infrastructure, starting with a public cloud virtual machine.

See you on [the fourth step](../3-simple-public-instance/README.md) of our journey.
