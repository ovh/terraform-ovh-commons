variable hosts {
  description = "Baremetal hosts to install"
  type        = map(string)
}

variable name {
  description = "Prefix for the node resources"
}

variable base_template_name {
  description = "Image to boot nodes from"
  default     = "ubuntu1804-server_64"
}

variable keypair {
  description = "SSH keypair to inject in the instance (previosly created in OpenStack)"
}

variable os_subnet_id {
  description = "Id of the network subnet to attach to"
}

variable bastion_host {
  description = "public ipv4 of bastion host"
}

variable bastion_user {
  description = "bastion ssh user"
  default     = "ubuntu"
}

variable vlan_id {
  description = "Vrack vlan id"
  default     = 1001
}
