variable region {
  description = "openstack region name"
}

variable name {
  description = "Prefix for the network name"
}

variable subnet_cidr {
  description = "Subnet CIDR"
  default     = "10.0.0.0/16"
}

variable dns_nameservers {
  type        = set(string)
  description = "DNS nameservers"
  default     = ["8.8.8.8", "8.8.4.4"]
}

variable bastion_image_name {
  description = "image name used for the ssh bastion host"
  default     = "Ubuntu 18.04"
}

variable bastion_flavor_name {
  description = "flavor name used for the ssh bastion host"
  default     = "s1-2"
}

variable remote_ssh_prefixes {
  description = "ipv4 prefixes allowed to connect to the ssh bastion host"
  default     = []
}

variable ssh_keypair {
  description = "ssh keypair allowed to connect to the ssh bastion host"
}
