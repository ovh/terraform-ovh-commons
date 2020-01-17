variable name {
  description = "Prefix for the security group name"
}

variable allowed_ingress_prefixes {
  type        = set(string)
  description = "Allowed ingress prefixes"
  default     = []
}

variable allowed_ingress_tcp {
  type        = set(string)
  description = "Allowed TCP ingress traffic"
  default     = []
}

variable allowed_ingress_udp {
  type        = set(string)
  description = "Allowed UDP ingress traffic"
  default     = []
}

variable allowed_sg_ids {
  type        = set(string)
  description = "Allowed secgroup"
  default     = []
}

variable allowed_ssh_sg_ids {
  type        = set(string)
  description = "Allowed secgroup for ssh traffic only"
  default     = []
}

variable ssh_port {
  description = "ssh tcp traffic port"
  default     = 22
}

variable allow_internal_traffic_from_sg {
  description = "If set to true, allowed_segroup_ids sg will allow ingress traffic from this secgroup"
  default     = true
}
