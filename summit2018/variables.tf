variable "count" {
  default  = 1
}

variable "iplb" {
   description = "the service name of your iplb"
}

variable "region_a" {
  description = "The id of the first openstack region"
  default = "SBG5"
}

variable "region_b" {
  description = "The id of the second openstack region"
  default = "GRA5"
}

variable "name" {
  description = "name of blog. Used to forge subdomain"
  default = "keynote2018"
}

variable "ssh_public_key" {
  description = "The path of the ssh public key that will be used"
  default     = "~/.ssh/id_rsa.pub"
}

variable "flavor_name" {
  description = "flavor name of nodes."
  default     = "s1-8"
}

variable "zone" {
  description = "the domain root zone"
}

variable "email" {
  description = "email for letsencrypt registration"
}
