terraform {
  backend "swift" {
    container = "demo-remote-state"
  }
}

provider "openstack" {
  auth_url  = "https://auth.cloud.ovh.net/v2.0/"
  region = "${var.region}"
}

resource "openstack_objectstorage_container_v1" "container" {
  region         = "${var.region}"
  name           = "${var.name}"
}
