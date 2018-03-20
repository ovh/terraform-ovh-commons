variable "region" {
  description = "The id of the openstack region"
  default = "GRA3"
}

variable "name" {
  description = "The name of the swift container for the terraform backend remote state"
  default = "demo-journey"
}

