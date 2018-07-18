- [Objective](#sec-1)
- [Pre requisites](#sec-2)
- [In pratice](#sec-4)
- [Going Further](#sec-5)


# Objective<a id="sec-1" name="sec-1"></a>

This document is the third part of a [step by step guide](../0-simple-terraform/README.md) on how to use 
the [Hashicorp Terraform](https://terraform.io) tool with [OVH Public Cloud](https://www.ovh.com/world/public-cloud/instances/). 
Here we'll create a Public Cloud instance to host a static blog based on [hugo](https://gohugo.io/getting-started/quick-start/). For that, we'll:
- prepare our environment to be multi-region ready (we'll use it later)
- see how to run post-install scripts on an instance
- see how to send files to an instance at boot time

# Pre requisites<a id="sec-2" name="sec-2"></a>

Please refer to the pre requisites paragraph of the [first part](../0-simple-terraform/README.md) of this guide.

In addition of the previous pre-requisites, we need to indroduce hugo to generate the website.

## Install Hugo: a popular static website generator

As this is not the main purpose of this tutorial, we'll provide you a simple static blog content generated with hugo.

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

# In pratice<a id="sec-4" name="sec-4"></a>

## Preparing the basics for starting an instance

We'll change a little bit the OpenStack provider to prepare for the multi-region use case. Let's edit 'main.tf'.

```terraform
provider "openstack" {
  version     = "= 1.5"
  region      = "${var.region_a}"
  alias = "region_a"
}
```

As you can see, we specify the version of the provider to freez it in our code. The reason is terraform move a lot and each new version comes with a lot of changes. We don't want a change on the OpenStack provider will impact our deployment. That's a good pratice for long terme code management.

Now let's add a network port, a keypair and the instance. As you can imagine, we are touching the dependancy notions. To start an instance which require an ssh keypair and a network port, terraform will first create the keypair and the port. Once it's available, terraform will create the instance. Those dependencies are implicit, terraform will create a dependancy tree before starting anything.

```terraform
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

resource "openstack_compute_keypair_v2" "keypair_a" {
  name       = "${var.name}"
  public_key = "${file(var.ssh_public_key)}"
  provider   = "openstack.region_a"
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
```

If you are attentive, you can identify two strange properties: count and network_id. 

"count" seems to come from variables but it's used in some properties with "count.index". This is a special property (called [interpolation syntax](https://www.terraform.io/docs/configuration/interpolation.html)) managed by terraform to perform special actions. Here it's to iterate on multiple resources. "count = 4" ask terraform to create 4 instances with the same properties. To differentiate those instances, we'll add this nomber in the name using the count.index interpolation syntax.

network_id is not defined anywhere but it comes from a data source. A data source is a source of data... A data soruce is a static data with a method to access it. Here we are speaking about the ID of the public network, we can get it simply by asking the OpenStack API.

```terraform
data "openstack_networking_network_v2" "public_a" {
  name     = "Ext-Net"
  provider = "openstack.region_a"
}
```

This will perform a request to Neutron to get the Ext-Net network ID.

Now we used a lot of variables, let's define its in 'variables.tf'.

```terraform
variable "region_a" {
  description = "The id of the first openstack region"
  default = "DE1"
}

variable "name" {
  description = "name of blog. Used to forge subdomain"
  default = "myblog"
}

variable "ssh_public_key" {
  description = "The path of the ssh public key that will be used"
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
```

Now we have the basics to start an instances. We'll see how to set up the instance with specific parameters at boot time.

## Configuring this instance

Back in 'main.tf', in the instance definition, there is a user_data property we still didn't speak about. This is what we are about to do, let's focus.

A user_data is a the "personality" of an instance, it's usually a [cloud-config](https://cloudinit.readthedocs.io/en/latest/index.html) syntax interpreted by cloud-init, a set of script ran at boot time on a cloud image. It can include system parameters, users configurations, simple file definitions, boot scripts to run...

A template_file can render a file based on a template! Awesome! It's done using '${data.template_file.userdata.rendered}'. We juste need to define 'data.template_file.userdata'

```terraform
data "template_file" "userdata" {
  template = <<CLOUDCONFIG
#cloud-config

write_files:
  - path: /tmp/setup/run.sh
    permissions: '0755'
    content: |
      ${indent(6, data.template_file.setup.rendered)}
  - path: /tmp/setup/myblog.conf
    permissions: '0644'
    content: |
      ${indent(6, data.template_file.myblog_conf.rendered)}
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

data "template_file" "myblog_conf" {
  template = "${file("${path.module}/myblog.conf.tpl")}"

  vars {
    server_name = "${var.name}.${var.zone}"
  }
}


```

This template include some files to add in the system (write_files) and a script to run at the end of the boot process (runcmd). The files to add are also template based.

```terraform
data "http" "myip" {
  url = "https://api.ipify.org"
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
```

This last template is based on a local file which can be customize before using it in terrafrom. Here is what 'myblog.conf.tpl' contains.

```terraform
<IfModule mod_ssl.c>
      <VirtualHost 0.0.0.0:80>
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
      </VirtualHost>
</IfModule>
```

As you can see, the variable '${server_name}' will be replaced by the terraform variable '${var.name}.${var.zone}'.

## Pushing more content on the instance

User data is a good solution to create simple file in an instance, but if you have more content to add on your system, you probably need to find another way to do it. This is our case for the whole 'www/public' local folder we want to add in the instance to be served by Apache.

Here come the terraform provisioners. It a couple of properties to define an scp command based on a trigger, some connection parameters and the content to push.

Still in 'main.tf', we'll add the following:

```terraform
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

# trick to filter ipv6 addrs
data "template_file" "ipv4_addr_a" {
  count    = "${var.count}"
  template = "${element(compact(split(",", replace(join(",", flatten(openstack_networking_port_v2.public_a.*.all_fixed_ips)), "/[[:alnum:]]+:[^,]+/", ""))), count.index)}"
}
```

Simple, right? When terraform will find a the resource 'openstack_compute_instance_v2.nodes_a.*.id[count.index]' ready, it will scp the 'www/public' folder in '/home/ubuntu/${var.name}' using the ubuntu user.

## Run Terraform

Now we can run terraform init:

```bash
source ~/openrc.sh
terraform init

Initializing the backend...

Successfully configured the backend "swift"! Terraform will automatically
use this backend unless the backend configuration changes.
...
```

# Going Further<a id="sec-5" name="sec-5"></a>

We're finished with terraform basics on OVH. Now we'll go deeper into bootstrapping 
real infrastructure, starting with a public cloud virtual machine.

See you on [the fourth step](../3-simple-public-instance/README.md) of our journey.
