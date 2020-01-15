variable region {
  description = "openstack region"
}

variable iplb_id {
  description = "id of the iplb"
}

variable name {
  description = "Stack name"
  default     = "vrack-iplb-demo"
}

variable subnet {
  description = "Network subnet prefix"
  default     = "10.0.0.0/16"
}

variable vlan_id {
  description = "Vrack vlan id"
  default     = 1001
}

variable subnet_nodes {
  description = "Network subnet prefix"
  default     = "10.0.0.0/24"
}

variable ports {
  description = "ports to load balance"
  type        = set(number)
  default     = [80, 443]
}

variable nodes {
  description = "Number of nodes"
  default     = 2
}

variable remote_ssh_prefixes {
  default = ["0.0.0.0/0"]
}

variable ssh_pubkey_path {
  description = "path to an ssh public key"
}
