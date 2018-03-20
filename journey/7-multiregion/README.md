- [Objective](#sec-1)
- [Pre requisites](#sec-2)
- [In pratice: OVH cloud: going multi regions](#sec-3)
- [<a id="org9355260"></a> Going Further](#sec-4)


# Objective<a id="sec-1"></a>

This document is the last part of a [step by step guide](../0-simple-terraform/README.md) on how to use the [Hashicorp Terraform](https://terraform.io) tool with [OVH Cloud](https://www.ovh.com/fr/public-cloud/instances/). This guide will make use of almost everything that can be done with terraform on OVH cloud, namely booting:

-   a cross region network
-   a bastion on region A
-   NAT gateways on both regions A & B
-   2 instances in private subnets on both regions A & B

This setup will make use of:

-   the terraform [openstack provider](https://www.terraform.io/docs/providers/openstack/index.html)
-   the terraform [OVH provider](https://www.terraform.io/docs/providers/ovh/index.html)
-   the [OVH network terraform module](https://registry.terraform.io/modules/ovh/publiccloud-network/ovh/)

# Pre requisites<a id="sec-2"></a>

Please refer to the pre requisites paragraph of the [first part](../0-simple-terraform/README.md) of this guide. This time be sure you have retrieve an OVH API consumer key.

# In pratice: OVH cloud: going multi regions<a id="sec-3"></a>

Here's how to boot a multi region setup on OVH public cloud.

We'll start with the usual remote state backend setup but also a more complex provider setup:

```terraform
# define a remote state backend on swift
terraform {
  backend "swift" {
    container = "demo-public-instance"
  }
}

# configure your ovh provider
provider "ovh" {
  version  = "~> 0.2"
  endpoint = "ovh-eu"
}

# configure your openstack provider to the first region
provider "openstack" {
  version = "~> 1.2"
  alias   = "regionA"
  region  = "${var.region_a}"
}

# configure your openstack provider to the second region
provider "openstack" {
  version = "~> 1.2"
  alias   = "regionB"
  region  = "${var.region_b}"
}
```

OK. Let's analyze what we've done here. We've setup a brand new provider of type "ovh". It means that we'll have to setup credentials at some point to be able to interact with the OVH API.

We've also setup 2 providers of type "openstack" targeting 2 different regions and set them specific aliases. We'll see how to make use of it.

Let's import our keypair:

```terraform
# Import Keypair by inlining your ssh public key using terraform interpolation 
# primitives (https://www.terraform.io/docs/configuration/interpolation.html)
# Import Keypair in both regions
resource "openstack_compute_keypair_v2" "keypair_a" {
  provider   = "openstack.regionA"
  name       = "${var.name}"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

resource "openstack_compute_keypair_v2" "keypair_b" {
  provider   = "openstack.regionB"
  name       = "${var.name}"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}
```

OH OH! Of course! In a multi region setup , our keypair has to be accessible in both regions. Thus we've created 2 resources instead of one, both targeting their specific provider!

We'll proceed with the rest of our setup following the same principle. But first, let's create our global cross region network:

```terraform
###
# Creation of the multiregion vrack network
###
resource "ovh_publiccloud_private_network" "net" {
  project_id = "${var.os_tenant_id}"
  name       = "${var.name}"
  regions    = ["${var.region_a}", "${var.region_b}"]
  vlan_id    = "111"
}


# create the network in region A
module "network_a" {
  source  = "ovh/publiccloud-network/ovh"
  version = ">= 0.1.0"

  network_name    = "${ovh_publiccloud_private_network.net.name}"
  create_network  = false
  name            = "${var.name}"
  cidr            = "${var.cidr}"
  region          = "${var.region_a}"

  # public subnets shall host instances with a public netif
  # such as NATs, bastions, vpns, load balancers, ...
  public_subnets  = ["${cidrsubnet(var.cidr, 8, 0)}"]

  # private subnets shall host backend instances. The dhcp agents
  # will push a default route through the according NAT gateway
  private_subnets = ["${cidrsubnet(var.cidr, 8, 1)}"]

  enable_nat_gateway = true
  single_nat_gateway = true
  nat_as_bastion     = true

  # the bastion host will receive the following ssh public keys
  ssh_public_keys = ["${openstack_compute_keypair_v2.keypair_a.public_key}"]

  providers = {
    "openstack" = "openstack.regionA"
  }
}

# create the network in region B
module "network_b" {
  source  = "ovh/publiccloud-network/ovh"
  version = ">= 0.1.0"

  network_name    = "${ovh_publiccloud_private_network.net.name}"
  create_network  = false
  name            = "${var.name}"
  cidr            = "${var.cidr}"
  region          = "${var.region_b}"

  # public subnets shall host instances with a public netif
  # such as NATs, bastions, vpns, load balancers, ...
  public_subnets  = ["${cidrsubnet(var.cidr, 8, 2)}"]

  # private subnets shall host backend instances. The dhcp agents
  # will push a default route through the according NAT gateway
  private_subnets = ["${cidrsubnet(var.cidr, 8, 3)}"]

  # ssh access to our instances in region B will go through the bastion host
  # in region A. No need for a bastion host here.
  enable_nat_gateway = true
  single_nat_gateway = true
  ssh_public_keys = []

  providers = {
    "openstack" = "openstack.regionB"
  }
}

```

Alright, it seems clear: we created the global network and then used the network module to create the subnets and networking components such as bastions and NATs in both regions.

Let's finish the setup:

```terraform
# get NATed IP to allow ssh only from terraform host
data "http" "myip" {
  url = "https://api.ipify.org/"
}

# allow remote ssh connection only for terraform host on region A
resource "openstack_networking_secgroup_rule_v2" "in_traffic_ssh_a" {
  provider          = "openstack.regionA"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  remote_ip_prefix  = "${trimspace(data.http.myip.body)}/32"
  port_range_min    = 22
  port_range_max    = 22
  security_group_id = "${module.network_a.nat_security_group_id}"
}
###
# instances region A
###

# create an anti-affinity server group.
# WARNING: You can't boot more than 5
# servers in one server group
resource "openstack_compute_servergroup_v2" "group_a" {
  provider = "openstack.regionA"
  name     = "${var.name}_a"
  policies = ["anti-affinity"]
}

# create subnet ports that will be attached to instances
resource "openstack_networking_port_v2" "ports_a" {
  provider       = "openstack.regionA"
  count          = "${var.count}"
  name           = "${var.name}_a_${count.index}"
  network_id     = "${module.network_a.network_id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${module.network_a.private_subnets[0]}"
  }
}

resource "openstack_compute_instance_v2" "instances_a" {
  provider    = "openstack.regionA"
  count       = "${var.count}"
  name        = "${var.name}_a_${count.index}"
  image_name  = "Centos 7"
  flavor_name = "s1-8"
  key_pair    = "${openstack_compute_keypair_v2.keypair_a.name}"

  user_data = <<USERDATA
#cloud-config
# add route to global network
bootcmd:
 - ip route add ${var.cidr} dev eth0 scope link metric 0
USERDATA

  network {
    port           = "${element(openstack_networking_port_v2.ports_a.*.id, count.index)}"
    access_network = true
  }

  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.group_a.id}"
  }
}

###
# instances region B
###

# create an anti-affinity server group.
# WARNING: You can't boot more than 5
# servers in one server group
resource "openstack_compute_servergroup_v2" "group_b" {
  provider = "openstack.regionB"
  name     = "${var.name}_b"
  policies = ["anti-affinity"]
}

# create subnet ports that will be attached to instances
resource "openstack_networking_port_v2" "ports_b" {
  provider       = "openstack.regionB"
  count          = "${var.count}"
  name           = "${var.name}_b_${count.index}"
  network_id     = "${module.network_b.network_id}"
  admin_state_up = "true"

  fixed_ip {
    subnet_id = "${module.network_b.private_subnets[0]}"
  }
}

resource "openstack_compute_instance_v2" "instances_b" {
  provider    = "openstack.regionB"
  count       = "${var.count}"
  name        = "${var.name}_b_${count.index}"
  image_name  = "Centos 7"
  flavor_name = "s1-8"
  key_pair    = "${openstack_compute_keypair_v2.keypair_b.name}"

  user_data = <<USERDATA
#cloud-config
# add route to global network
bootcmd:
 - ip route add ${var.cidr} dev eth0 scope link metric 0
USERDATA

  network {
    port           = "${element(openstack_networking_port_v2.ports_b.*.id, count.index)}"
    access_network = true
  }

  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.group_b.id}"
  }
}

```

We're done with the setup. Let's try to apply it:

```bash
source ~/openrc.sh
source ~/ovhrc
terraform init
terraform apply -auto-approve -var os_tenant_id=$OS_TENANT_ID
```

Notice the `source ovhrc` command!

    Initializing the backend...
    
    Successfully configured the backend "swift"! Terraform will automatically
    use this backend unless the backend configuration changes.
    ...
    scheduler_hints.370470165.query.#:            "" => "0"
      scheduler_hints.370470165.same_host.#:        "" => "0"
      scheduler_hints.370470165.target_cell:        "" => ""
      security_groups.#:                            "" => "<computed>"
      stop_before_destroy:                          "" => "false"
      user_data:                                    "" => "3fcdeb19653f1b9522fa0fe31fb5eff64916e6c6"
    openstack_compute_instance_v2.instances_a.0: Still creating... (10s elapsed)
    openstack_compute_instance_v2.instances_a.1: Still creating... (10s elapsed)
    openstack_compute_instance_v2.instances_a.0: Still creating... (20s elapsed)
    openstack_compute_instance_v2.instances_a.1: Still creating... (20s elapsed)
    openstack_compute_instance_v2.instances_a[0]: Creation complete after 26s (ID: f2dfa17c-39a2-481a-bb4d-3067740b9cc6)
    openstack_compute_instance_v2.instances_a[1]: Creation complete after 26s (ID: 5ef14450-5844-4ad1-b968-c11d6680e22f)
    
    Apply complete! Resources: 37 added, 0 changed, 0 destroyed.
    
    Outputs:
    
    helper = You can now connect to your instances in region A:
       $ ssh -J core@a.b.c.d centos@10.0.1.9
       $ ssh -J core@a.b.c.d centos@10.0.1.12
    
    You can now connect to your instances in region B:
       $ ssh -J core@a.b.c.d centos@10.0.3.4
       $ ssh -J core@a.b.c.d centos@10.0.3.3

Whooooooooo. Let's try to ping:

    ssh -J core@a.b.c.d centos@10.0.1.9                                                                                                                     ✘ 255
    The authenticity of host 'a.b.c.d (a.b.c.d)' can't be established.
    ECDSA key fingerprint is SHA256:...
    ECDSA key fingerprint is MD5:...
    Are you sure you want to continue connecting (yes/no)? yes
    Warning: Permanently added 'a.b.c.d' (ECDSA) to the list of known hosts.
    The authenticity of host '10.0.1.9 (<no hostip for proxy command>)' can't be established.
    ECDSA key fingerprint is SHA256:...
    ECDSA key fingerprint is MD5:...
    Are you sure you want to continue connecting (yes/no)? yes
    Warning: Permanently added '10.0.1.9' (ECDSA) to the list of known hosts.
    [centos@demo-multiregion-a-0 ~]$ ping 10.0.3.4
    PING 10.0.3.4 (10.0.3.4) 56(84) bytes of data.
    64 bytes from 10.0.3.4: icmp_seq=1 ttl=64 time=20.8 ms
    64 bytes from 10.0.3.4: icmp_seq=2 ttl=64 time=9.75 ms
    ^C
    --- 10.0.3.4 ping statistics ---
    2 packets transmitted, 2 received, 0% packet loss, time 1001ms
    rtt min/avg/max/mdev = 9.757/15.292/20.827/5.535 ms
    [centos@demo-multiregion-a-0 ~]$ ping 10.0.1.12
    PING 10.0.1.12 (10.0.1.12) 56(84) bytes of data.
    64 bytes from 10.0.1.12: icmp_seq=1 ttl=64 time=1.56 ms
    64 bytes from 10.0.1.12: icmp_seq=2 ttl=64 time=0.420 ms
    64 bytes from 10.0.1.12: icmp_seq=3 ttl=64 time=0.405 ms
    ^C
    --- 10.0.1.12 ping statistics ---
    3 packets transmitted, 3 received, 0% packet loss, time 2001ms
    rtt min/avg/max/mdev = 0.405/0.795/1.562/0.542 ms
    [centos@demo-multiregion-a-0 ~]$

Ooooh. And the other way around: let's ssh into a host in region B through the bastion host in region A and ping.

    ssh -J core@a.b.c.d centos@10.0.3.4
    The authenticity of host '10.0.3.4 (<no hostip for proxy command>)' can't be established.
    ECDSA key fingerprint is SHA256:...
    ECDSA key fingerprint is MD5:...
    Are you sure you want to continue connecting (yes/no)? yes
    Warning: Permanently added '10.0.3.4' (ECDSA) to the list of known hosts.
    [centos@demo-multiregion-b-0 ~]$ ping 10.0.1.9
    PING 10.0.1.9 (10.0.1.9) 56(84) bytes of data.
    64 bytes from 10.0.1.9: icmp_seq=1 ttl=64 time=10.2 ms
    64 bytes from 10.0.1.9: icmp_seq=2 ttl=64 time=9.81 ms
    ^C
    --- 10.0.1.9 ping statistics ---
    2 packets transmitted, 2 received, 0% packet loss, time 1001ms
    rtt min/avg/max/mdev = 9.819/10.046/10.274/0.248 ms
    [centos@demo-multiregion-b-0 ~]$

It was almost too easy, wasn't it?

It seems that we're done with our journey. We hope that you'll enjoy our platform. Please feel free to come back at us and log issues if you encountered any problem during this journey or give us any feedback you'd like.

We have some more things to share with you in [Going further](#org9355260), but before, don't forget to destroy your instances:

```bash
source ~/openrc.sh
source ~/ovhrc
terraform destroy -force -var os_tenant_id=$OS_TENANT_ID
...

```

    ...
    module.network_b.openstack_networking_port_v2.port_nats: Destruction complete after 5s
    module.network_b.openstack_networking_subnet_v2.public_subnets: Destroying... (ID: d630a384-44a3-4dc7-8ba2-f138a4c1e0d2)
    module.network_b.openstack_networking_port_v2.public_port_nats: Destruction complete after 5s
    module.network_b.openstack_networking_secgroup_v2.nat_sg: Destroying... (ID: 88550cc3-933d-4591-9dc4-9893bd1b8d27)
    module.network_a.openstack_networking_subnet_v2.public_subnets: Still destroying... (ID: 8b087f5b-3d30-4ad0-a650-e33196bdf37f, 10s elapsed)
    module.network_a.openstack_networking_secgroup_v2.nat_sg: Still destroying... (ID: 7a723b1f-5cdc-4b5d-885d-aff9c462e2d2, 10s elapsed)
    module.network_b.openstack_networking_subnet_v2.public_subnets: Still destroying... (ID: d630a384-44a3-4dc7-8ba2-f138a4c1e0d2, 10s elapsed)
    module.network_b.openstack_networking_secgroup_v2.nat_sg: Still destroying... (ID: 88550cc3-933d-4591-9dc4-9893bd1b8d27, 10s elapsed)
    module.network_a.openstack_networking_secgroup_v2.nat_sg: Destruction complete after 13s
    module.network_b.openstack_networking_secgroup_v2.nat_sg: Destruction complete after 14s
    module.network_b.openstack_networking_subnet_v2.public_subnets: Destruction complete after 14s
    module.network_a.openstack_networking_subnet_v2.public_subnets: Destruction complete after 14s
    ovh_publiccloud_private_network.net: Destroying... (ID: pn-1041336_111)
    ovh_publiccloud_private_network.net: Still destroying... (ID: pn-1041336_111, 10s elapsed)
    ovh_publiccloud_private_network.net: Destruction complete after 17s
    
    Destroy complete! Resources: 37 destroyed.

# <a id="org9355260"></a> Going Further<a id="sec-4"></a>

So this is the end of the journey. We've stepped through a lot of concepts and we hope you've learned a lot of things.

But if you're still hungry, it's time for you for a deep dive in our [terraform modules](https://registry.terraform.io/search?q=ovh&verified=false) starting with [Kubernetes](https://github.com/ovh/terraform-ovh-publiccloud-k8s)!

See you soon and thanks again
