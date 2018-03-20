resource "openstack_objectstorage_container_v1" "backend" {
  region         = "SBG3"
  name           = "demo-simple-terraform"
}
