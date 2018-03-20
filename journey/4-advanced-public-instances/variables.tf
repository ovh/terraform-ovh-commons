variable "region" {
  description = "The id of the openstack region"
  default = "DE1"
}

variable "name" {
  description = "The name of the resources"
  default = "demo-public-advanced"
}

variable "count" {
  description = "number of instances"
  default     = 3
}
