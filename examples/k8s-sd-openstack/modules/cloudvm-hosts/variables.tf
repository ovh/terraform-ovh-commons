variable nb {
  description = "Number of nodes to be created"
}

variable name {
  description = "Prefix for the node resources"
}

variable flavor_name {
  description = "Flavor to be used for nodes"
  default     = "b2-7"
}

variable image_name {
  description = "Image to boot nodes from"
  default     = "Ubuntu 18.04"
}

variable keypair {
  description = "SSH keypair to inject in the instance (previosly created in OpenStack)"
}

variable subnet_id {
  description = "Id of the network subnet to attach nodes to"
}

variable secgroup_id {
  description = "id of the security group for nodes"
}

variable assign_floating_ip {
  description = "If true a floating IP will be attached to nodes"
  default     = false
}

variable floating_ip_pool {
  description = "Name of the floating IP pool (don't leave it empty if assign_floating_ip is true)"
  default     = "Ext-Net"
}

variable ssh_user {
  description = "Ssh username"
  default     = "ubuntu"
}

variable bastion_host {
  description = "Ssh bastion host"
}

variable bastion_user {
  description = "Ssh username for bastion"
  default     = "ubuntu"
}
