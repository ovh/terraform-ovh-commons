variable "region" {
  description = "The id of the openstack region"
  default     = "DE1"
}

variable "name" {
  description = "The name of the resources"
  default     = "demo-modules"
}

variable "count" {
  description = "number of instances"
  default     = 3
}

variable "cidr" {
  description = "the cidr of the network"
  default     = "10.0.0.0/16"
}
