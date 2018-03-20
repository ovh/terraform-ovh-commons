- [Objective](#sec-1)
- [Pre requisites](#sec-2)
- [In pratice: OVH cloud: public instances](#sec-3)
- [Going Further](#sec-4)


# Objective<a id="sec-1"></a>

This document is the fifth part of a [step by step guide](../0-simple-terraform/README.md) on how to use the [Hashicorp Terraform](https://terraform.io) tool with [OVH Cloud](https://www.ovh.com/fr/public-cloud/instances/). It will help you create multiple openstack public instances on the region of your choice, using networking ports and custom ecurity groups.

# Pre requisites<a id="sec-2"></a>

Please refer to the pre requisites paragraph of the [first part](../0-simple-terraform/README.md) of this guide.

# In pratice: OVH cloud: public instances<a id="sec-3"></a>

Here's how to boot multiple instances on OVH public cloud behind a security group using terraform.

First, and as usual, configure your state backend, your openstack provider and import your ssh public key:

```terraform
# define a remote state backend on swift
terraform {
  backend "swift" {
    container = "demo-public-instance"
  }
}

# configure your openstack provider to target the region of your choice
provider "openstack" {
  region = "${var.region}"
}

# Import Keypair by inlining your ssh public key using terraform interpolation 
# primitives (https://www.terraform.io/docs/configuration/interpolation.html)
resource "openstack_compute_keypair_v2" "keypair" {
  name       = "${var.name}"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}
```

Then, if you don't want your instances to be opened to the whole internet, you can create a security group and allow remote access to the ssh 22 port only to your internet IP.

```terraform
# get NATed IP to allow ssh only from terraform host
data "http" "myip" {
  url = "https://api.ipify.org"
}

# create the security group to which the instances & ports will be associated
resource "openstack_networking_secgroup_v2" "sg" {
  name        = "${var.name}_ssh_sg"
  description = "${var.name} security group"
}

# allow remote ssh connection only for terraform host
resource "openstack_networking_secgroup_rule_v2" "in_traffic_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "${trimspace(data.http.myip.body)}/32"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = "${openstack_networking_secgroup_v2.sg.id}"
}
```

As you may have noticed, we introduced a new kind of terraform primitives: data sources. Data sources are useful to retrieve information you don't have access to at the moment you write the script, or that depends on the environment, such as IDs. Here, the data source we use is useful to get your internet IPv4 to filter ssh access only to your IP.

Now we will allow inter instances communication and egress traffic to 0.0.0.0/0:

```terraform

# allow ingress traffic inter instances
resource "openstack_networking_secgroup_rule_v2" "ingress_instances" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = "${openstack_networking_secgroup_v2.sg.id}"
  security_group_id = "${openstack_networking_secgroup_v2.sg.id}"
}

# allow egress traffic worldwide
resource "openstack_networking_secgroup_rule_v2" "egress_instances" {
  direction         = "egress"
  ethertype         = "IPv4"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.sg.id}"
}
```

Next step is useful when you want to be sure your instances don't run on the same OVH host. To do this, you create a server group with an anti-affinity constraint. You have to know though that server groups have a max capacity of 5 nodes. But in HA deployments, this should be sufficient. If you have need for larger constraints, then you should consider multi regions deployments.

```terraform
# create an anti-affinity server group.
# WARNING: You can't boot more than 5
# servers in one server group
resource "openstack_compute_servergroup_v2" "group" {
  name     = "${var.name}"
  policies = ["anti-affinity"]
}
```

To bootstrap the instances, this time we will make use of networking ports. This has a major advantage: your IP addresses can survive instances destroys.

```terraform
# use a data source to retrieve Ext-Net network id for your target region
data "openstack_networking_network_v2" "ext_net" {
  name      = "Ext-Net"
  tenant_id = ""
}

# create a port before the instances allows you
# to keep your IP when you taint an instance
resource "openstack_networking_port_v2" "public_port" {
  count = "${var.count}"

  name               = "${var.name}_${count.index}"
  network_id         = "${data.openstack_networking_network_v2.ext_net.id}"
  admin_state_up     = "true"

  # the security groups are attached to the ports, not the instance.
  security_group_ids = ["${openstack_networking_secgroup_v2.sg.id}"]
}
```

Notice the second use of a datasource to retrieve an ID, and the "count" terraform feature to create multiple resource at a time.

We're almost done. We now have described all the necessary resources to boot our instances:

```terraform
# create instances
resource "openstack_compute_instance_v2" "instances" {
  # instance count : same as port count
  count           = "${var.count}"
  # name the instances according to the count number
  name            = "${var.name}_${count.index}"

  # Choose your base image from our catalog
  image_name  = "Centos 7"

  # Choose a flavor type
  flavor_name = "s1-8"

  # Target your brand new keypair
  key_pair    = "${openstack_compute_keypair_v2.keypair.name}"

  # Attach your VM to the according ports
  network {
    port           = "${element(openstack_networking_port_v2.public_port.*.id, count.index)}"
    access_network = true
  }

  # Place the instances in the constrained server group
  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.group.id}"
  }
}
```

And apply it:

```bash
source ~/openrc.sh
terraform init
terraform apply -auto-approve
```

    Initializing the backend...
    
    Successfully configured the backend "swift"! Terraform will automatically
    use this backend unless the backend configuration changes.
    ...
    openstack_compute_instance_v2.instances.0: Still creating... (40s elapsed)
    openstack_compute_instance_v2.instances.0: Still creating... (50s elapsed)
    openstack_compute_instance_v2.instances.0: Still creating... (1m0s elapsed)
    openstack_compute_instance_v2.instances.0: Still creating... (1m10s elapsed)
    openstack_compute_instance_v2.instances[0]: Creation complete after 1m17s (ID: 237434cc-7892-48c1-acb0-77c77df3d772)
    
    Apply complete! Resources: 12 added, 0 changed, 0 destroyed.
    
    Outputs:
    
    helper = You can now connect to your instances:
       $ ssh centos@a.b.c.d
       $ ssh centos@e.f.g.h
       $ ssh centos@i.j.k.l

How fun again! You can now ssh into your centos boxes by pasting the output helper. And start to ping&#x2026;

    ssh centos@a.b.c.d
    ...
    [centos@demo-public-advanced-0 ~]$ ping e.f.g.h
    PING e.f.g.h (e.f.g.h) 56(84) bytes of data.
    64 bytes from e.f.g.h: icmp_seq=1 ttl=59 time=0.495 ms
    64 bytes from e.f.g.h: icmp_seq=2 ttl=59 time=0.527 ms
    [centos@demo-public-advanced-0 ~]$

Don't forget to destroy your instance once done:

```bash
source ~/openrc.sh
terraform destroy -force
...
```

    openstack_compute_keypair_v2.keypair: Refreshing state... (ID: demo-public-instance)
    openstack_compute_instance_v2.instance: Refreshing state... (ID: da3be2fb-429f-427d-acc3-d5e9262ab460)
    openstack_compute_instance_v2.instance: Destroying... (ID: da3be2fb-429f-427d-acc3-d5e9262ab460)
    openstack_compute_instance_v2.instance: Still destroying... (ID: da3be2fb-429f-427d-acc3-d5e9262ab460, 10s elapsed)
    openstack_compute_instance_v2.instance: Destruction complete after 10s
    openstack_compute_keypair_v2.keypair: Destroying... (ID: demo-public-instance)
    openstack_compute_keypair_v2.keypair: Destruction complete after 0s
    
    Destroy complete! Resources: 12 destroyed.

# Going Further<a id="sec-4"></a>

Public instances are fun. But private instances are somewhat kind of useful. Next time we'll introduce private instances and the Vrack.

See you on [the sixth step](../5-private-instances/README.md) of our journey.
