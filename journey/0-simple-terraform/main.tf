provider "openstack" {
  auth_url  = "https://auth.cloud.ovh.net/v3/"
}

resource "openstack_objectstorage_container_v1" "backend" {
  name           = "demo-simple-terraform"
}
