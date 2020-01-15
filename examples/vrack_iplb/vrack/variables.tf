variable region {
  description = "openstack region"
}

variable vrack_id {
  description = "id of the iplb"
}

variable iplb_id {
  description = "id of the iplb"
}

variable name {
  description = "Stack name"
  default     = "vrack-iplb-demo"
}

variable vlan_id {
  description = "Vrack vlan id"
  default     = 1001
}

variable subnet {
  description = "Network subnet prefix"
  default     = "10.0.0.0/16"
}

variable subnet_iplb {
  description = "Network subnet prefix"
  default     = "10.0.250.0/24"
}

