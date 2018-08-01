
variable "region_a" {
  description = "The id of the first openstack region"
  default = "DE1"
}

variable "name" {
  description = "name of blog. Used to forge subdomain"
  default = "myblog"
}

variable "ssh_public_key" {
  description = "The path of the ssh public key that will be used"
  default     = "~/.ssh/id_rsa.pub"
}

variable "flavor_name" {
  description = "flavor name of nodes."
  default     = "s1-2"
}

variable "count" {
  description = "number of blog nodes per region"
  default     = 1
}

variable "zone" {
  description = "the domain root zone"
}
