variable "os_tenant_id" {
  description = "the id of the openstack tenant"
}

variable "region_a" {
  description = "The id of the openstack region a"
  default     = "DE1"
}

variable "region_b" {
  description = "The id of the openstack region b"
  default     = "GRA3"
}

variable "name" {
  description = "The name of the resources"
  default     = "demo-multiregion"
}

variable "count" {
  description = "number of instances per region"
  default     = 2
}

variable "cidr" {
  description = "the cidr of the network"
  default     = "10.0.0.0/16"
}
