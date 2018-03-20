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

# Create your Virtual Machine
resource "openstack_compute_instance_v2" "instance" {
  name        = "${var.name}"

  # Choose your base image from our catalog
  image_name  = "Centos 7"

  # Choose a flavor type
  flavor_name = "s1-8"

  # Target your brand new keypair
  key_pair    = "${openstack_compute_keypair_v2.keypair.name}"

  # Attach your VM to the public network
  network {
    name = "Ext-Net"
    access_network = true
  }
}
