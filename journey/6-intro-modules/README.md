- [Objective](#sec-1)
- [Pre requisites](#sec-2)
- [In pratice: OVH cloud: private instances](#sec-3)
- [Going Further](#sec-4)


# Objective<a id="sec-1"></a>

This document is the seventh part of a [step by step guide](../0-simple-terraform/README.md) on how to use the [Hashicorp Terraform](https://terraform.io) tool with [OVH Cloud](https://www.ovh.com/fr/public-cloud/instances/). We're getting near the end. It will help you create private instances with internet access on the region of your choice and connect to it via a simple bastion host by making use of the [OVH terraform modules](https://registry.terraform.io/search?q=ovh&verified=false).

# Pre requisites<a id="sec-2"></a>

Please refer to the pre requisites paragraph of the [first part](../0-simple-terraform/README.md) of this guide.

# In pratice: OVH cloud: private instances<a id="sec-3"></a>

Here's how to boot private instances on OVH public cloud using terraform and OVH [network module](https://registry.terraform.io/modules/ovh/publiccloud-network/ovh).

Terraform [modules](https://www.terraform.io/docs/modules/index.html) are a simple way to package terraform scripts and make them available for reuse. As a terraform script takes arguments and has outputs, it makes it easy to include a terraform script as simple "function call".

We'll start as usual with a basic terraform setup with a remote state backend, openstack provider targeting our region and a keypair:

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

And call the network module that will be responsible for creating the network, subnets, bastion and NAT Internet gateways:

```terraform
###
# Use of the OVH network module
###
module "network" {
  source = "ovh/publiccloud-network/ovh"
  version = ">= 0.1.0"

  name            = "${var.name}"
  cidr            = "${var.cidr}"
  region          = "${var.region}"

  # public subnets shall host instances with a public netif
  # such as NATs, bastions, vpns, load balancers, ...
  public_subnets  = ["${cidrsubnet(var.cidr, 4, 0)}"]

  # private subnets shall host backend instances. The dhcp agents
  # will push a default route through the according NAT gateway
  private_subnets = ["${cidrsubnet(var.cidr, 4, 1)}"]

  enable_nat_gateway = true
  enable_bastion_host  = true

  # the bastion host will receive the following ssh public keys
  ssh_public_keys = ["${openstack_compute_keypair_v2.keypair.public_key}"]
}
```

The module will have several outputs, such as the network and subnets ids, but also security groups and instances IPv4s. We will reuse these resources in the following:

```terraform
# get NATed IP to allow ssh only from terraform host
data "http" "myip" {
  url = "https://api.ipify.org"
}


# allow remote ssh connection only for terraform host
resource "openstack_networking_secgroup_rule_v2" "in_traffic_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "${data.http.myip.body}/32"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = "${module.network.nat_security_group_id}"
}
```

And boot our instances as usual:

```terraform
# create an anti-affinity server group.
# WARNING: You can't boot more than 5
# servers in one server group
resource "openstack_compute_servergroup_v2" "group" {
  name     = "${var.name}"
  policies = ["anti-affinity"]
}

# create subnet ports that will be attached to instances
resource "openstack_networking_port_v2" "ports" {
  count          = "${var.count}"
  name           = "${var.name}_${count.index}"
  network_id     = "${module.network.network_id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${module.network.private_subnets[0]}"
  }
}

resource "openstack_compute_instance_v2" "instances" {
  count           = "${var.count}"
  name            = "${var.name}_${count.index}"
  image_name      = "Centos 7"
  flavor_name     = "s1-8"
  key_pair        = "${openstack_compute_keypair_v2.keypair.name}"

  network {
    port           = "${element(openstack_networking_port_v2.ports.*.id, count.index)}"
    access_network = true
  }

  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.group.id}"
  }
}
```

We're done with the setup. Let's try to apply it:

```bash
source ~/openrc.sh
terraform init
terraform apply -auto-approve
```

    Initializing the backend...
    
    Successfully configured the backend "swift"! Terraform will automatically
    use this backend unless the backend configuration changes.
    ...
    data.http.myip: Refreshing state...
    data.ignition_networkd_unit.nat_eth1: Refreshing state...
    data.ignition_networkd_unit.bastion_eth0: Refreshing state...
    data.ignition_networkd_unit.bastion_eth1: Refreshing state...
    data.ignition_networkd_unit.nat_eth0: Refreshing state...
    data.openstack_networking_network_v2.ext_net: Refreshing state...
    openstack_compute_servergroup_v2.group: Creating...
      members.#:  "" => "<computed>"
      name:       "" => "demo-modules"
      policies.#: "" => "1"
      policies.0: "" => "anti-affinity"
      region:     "" => "<computed>"
    module.network.openstack_networking_network_v2.net: Creating...
      admin_state_up:            "" => "true"
      availability_zone_hints.#: "" => "<computed>"
      name:                      "" => "demo-modules"
      region:                    "" => "<computed>"
      shared:                    "" => "<computed>"
      tenant_id:                 "" => "<computed>"
    openstack_compute_keypair_v2.keypair: Creating...
    ...
    module.network.openstack_compute_instance_v2.bastion: Creation complete after 2m49s (ID: 4d2ab08a-fdc5-4b5a-8e15-3c8231abe93d)
    
    Apply complete! Resources: 25 added, 0 changed, 0 destroyed.
    
    Outputs:
    
    helper = You can now connect to your instances:
       $ ssh -J core@a.b.c.d centos@10.0.16.9
       $ ssh -J core@a.b.c.d centos@10.0.16.5
       $ ssh -J core@a.b.c.d centos@10.0.16.7

Great! You can now ssh into your centos box by pasting the output helper and ping internet!

    sh -J core@a.b.c.d centos@10.0.16.9
    The authenticity of host 'a.b.c.d (a.b.c.d)' can't be established.
    ECDSA key fingerprint is SHA256:...
    ECDSA key fingerprint is MD5:...
    Are you sure you want to continue connecting (yes/no)? yes
    Warning: Permanently added 'a.b.c.d' (ECDSA) to the list of known hosts.
    The authenticity of host '10.0.16.9 (<no hostip for proxy command>)' can't be established.
    ECDSA key fingerprint is SHA256:...
    ECDSA key fingerprint is MD5:...
    Are you sure you want to continue connecting (yes/no)? yes
    Warning: Permanently added '10.0.16.9' (ECDSA) to the list of known hosts.
    [centos@demo-modules-0 ~]$ ping ovh.fr
    PING ovh.fr (198.27.92.16) 56(84) bytes of data.
    64 bytes from www.ovh.lt (198.27.92.16): icmp_seq=1 ttl=53 time=9.02 ms
    64 bytes from www.ovh.lt (198.27.92.16): icmp_seq=2 ttl=53 time=9.19 ms
    64 bytes from www.ovh.lt (198.27.92.16): icmp_seq=3 ttl=53 time=9.37 ms
    ^C
    --- ovh.fr ping statistics ---
    3 packets transmitted, 3 received, 0% packet loss, time 2003ms
    rtt min/avg/max/mdev = 9.022/9.198/9.378/0.165 ms
    [centos@demo-modules-0 ~]$

Here we are, almost achieving our journey. Next and last step will be to boot a multi region setup. But before, don't forget to destroy your instances:

```bash
source ~/openrc.sh
terraform destroy -force
...
```

    ...
    module.network.openstack_compute_instance_v2.nats: Destroying... (ID: 25e543c9-3215-44d7-b054-2b3ec3b02564)
    module.network.openstack_networking_subnet_v2.private_subnets: Destroying... (ID: c8506277-1594-4a6c-ba9b-a84500e63b75)
    module.network.openstack_networking_secgroup_v2.bastion_sg: Destruction complete after 8s
    module.network.openstack_networking_subnet_v2.private_subnets: Destruction complete after 9s
    module.network.openstack_compute_instance_v2.nats: Still destroying... (ID: 25e543c9-3215-44d7-b054-2b3ec3b02564, 10s elapsed)
    module.network.openstack_compute_instance_v2.nats: Destruction complete after 10s
    openstack_compute_keypair_v2.keypair: Destroying... (ID: demo-modules)
    module.network.openstack_networking_port_v2.public_port_nats: Destroying... (ID: a1e9c7e9-51d7-48b6-9d76-79398f3c124f)
    module.network.openstack_networking_port_v2.port_nats: Destroying... (ID: f6a75828-392d-4e83-a8df-4640df1f2c9c)
    module.network.openstack_compute_servergroup_v2.nats: Destroying... (ID: c174d8fd-9956-4b92-b58b-f8675247b51e)
    openstack_compute_keypair_v2.keypair: Destruction complete after 0s
    module.network.openstack_compute_servergroup_v2.nats: Destruction complete after 0s
    module.network.openstack_networking_port_v2.port_nats: Destruction complete after 9s
    module.network.openstack_networking_subnet_v2.public_subnets: Destroying... (ID: 02833e19-1bcb-49ac-a0f7-a947c25b408f)
    module.network.openstack_networking_port_v2.public_port_nats: Destruction complete after 9s
    module.network.openstack_networking_secgroup_v2.nat_sg: Destroying... (ID: 162ba26c-c559-46fc-9ce7-f6646721f48b)
    module.network.openstack_networking_secgroup_v2.nat_sg: Destruction complete after 8s
    module.network.openstack_networking_subnet_v2.public_subnets: Destruction complete after 9s
    module.network.openstack_networking_network_v2.net: Destroying... (ID: 09aaf69b-835f-4dbb-a51f-c5c28d75440d)
    module.network.openstack_networking_network_v2.net: Destruction complete after 9s
    
    Destroy complete! Resources: 25 destroyed.

# Going Further<a id="sec-4"></a>

Almost the end of the journey: last step will show you how to make use of the VRack to boot a multi region setup

See you on [the last step](../7-multiregion/README.md) of our journey.
