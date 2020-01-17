variable region {
  description = "openstack region"
}

variable vrack_id {
  description = "id of the iplb"
}

variable dedicated_servers_ids {
  description = "service names of your dedicated servers"
  type        = set(string)
}

variable name {
  description = "Stack name"
  default     = "sd-os-demo"
}

variable vlan_id {
  description = "Vrack vlan id"
  default     = 1001
}
