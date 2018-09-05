variable "name" {
  description = "name of blog. Used to forge subdomain"
  default     = "myblog"
}

variable "project_id" {
  description = "The id of the cloud project"
}

variable "admin_network_vlan_id" {
  description = "the admin network vlan id"
  default     = "1001"
}

variable "admin_cidr" {
  description = "the network admin cidr"
  default     = "10.0.0.0/16"
}

variable "public_cidr" {
  description = "the network global cidr"
}

variable "public_gateway" {
  description = "the network global cidr"
}

variable "public_subnet_pool_start" {
  description = "the public network pool start. if left blank, first ip of the network will be used"
  default     = ""
}

variable "public_subnet_pool_end" {
  description = "the public network pool end. if left blank, last ip of the subnet will be used"
  default     = ""
}

variable "dns_nameservers" {
  type        = "list"
  description = "The list of dns servers to be pushed by dhcp"
  default     = ["213.186.33.99", "8.8.8.8"]
}

variable "region_a" {
  description = "The target openstack region"
  default     = "DE1"
}

variable "region_b" {
  description = "The target openstack region"
  default     = "WAW1"
}

variable "ssh_public_key" {
  description = "The path of the ssh public key that will be used by ansible to provision the hosts"
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

variable "email" {
  description = "email for letsencrypt registration"
}

variable "vrrp_password" {
  description = "the vrrp password for keepalived"
  default     = "vrrp_password"
}
