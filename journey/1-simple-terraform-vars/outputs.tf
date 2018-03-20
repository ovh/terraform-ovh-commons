output "helper" {
  description = "human friendly helper"
  value = <<DESC
You can now use your swift container as a terraform remote state backend, such as:
---
terraform {
  backend "swift" {
    container = "${openstack_objectstorage_container_v1.container.name}"
  }
}
---

and reference state outputs with:
---
data "terraform_remote_state" "foo" {
  backend = "swift"
  config {
    container = "${openstack_objectstorage_container_v1.container.name}"
  }
}
---
DESC
}
