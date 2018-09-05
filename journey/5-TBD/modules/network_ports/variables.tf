variable "name" {
  description = "name of the resources"
}

variable "count" {
  description = "number of blog nodes"
}

variable "remote_ip_prefix" {
  description = "the remote ip prefix to authorize ssh connection from"
}

variable "public_network_name" {
  description = "The public network name which must be set on vlan 0"
}

variable "public_cidr" {
  description = "the network global cidr"
}

variable "public_gateway" {
  description = "the network global cidr"
}

variable "public_subnet_pool_start" {
  description = "the public network pool start"
}

variable "public_subnet_pool_end" {
  description = "the public network pool end"
}

variable "admin_network_name" {
  description = "The admin network name"
}

variable "admin_cidr" {
  description = "the network global cidr"
}

variable "admin_subnet_pool_start" {
  description = "the admin network pool start"
}

variable "admin_subnet_pool_end" {
  description = "the admin network pool end"
}

variable "dns_nameservers" {
  type        = "list"
  description = "The list of dns servers to be pushed by dhcp"
  default     = ["213.186.33.99", "8.8.8.8"]
}
