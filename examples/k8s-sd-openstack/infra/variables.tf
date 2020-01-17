variable name {
  description = "Stack name"
  default     = "sd-os-demo"
}

variable region {
  description = "Openstack region"
}

variable remote_ssh_prefixes {
  description = "ipv4 prefixes allowed to connect to the ssh bastion host"
  default     = ["0.0.0.0/0"]
}

variable remote_ip_prefixes {
  description = "ipv4 prefixes allowed to connect to the nodes through standard ports"
  default     = ["0.0.0.0/0"]
}

variable masters_nb {
  description = "Number of Cloud VM"
  default     = 3
}

variable cloudvm_nb {
  description = "Number of Cloud VM"
  default     = 1
}

variable baremetal_hosts {
  description = "Baremetal hosts defined as service_name: hostname"
  default = {
    "ns31119486.ip-51-91-6.eu" = "bm-host-0"
  }
}

variable kubespray_playbook {
  description = "Kubespray ansible playbook to run"
  default     = "cluster.yml"
}

variable kubespray_args {
  description = "Optional Kubespray ansible args"
  default     = ""
}

variable vlan_id {
  description = "Vrack vlan id"
  default     = 1001
}
