variable "ssh_public_key" {
  description = "The path of the ssh public key that will be used by ansible to provision the hosts"
}

variable "count" {
  description = "number of blog nodes"
}

variable "name" {
  description = "name of the resources"
}

variable "flavor_name" {
  description = "flavor name of nodes."
  default     = "s1-2"
}

variable "remote_ip_prefix" {
  description = "the remote ip prefix to authorize ssh connection from"
}

variable "fqdn" {
  description = "fqdn of the blog"
}

variable "tls_private_key_pem" {
  description = "the tls private key pem"
}

variable "tls_issuer_pem" {
  description = "the tls issuer pem"
}

variable "tls_certificate_pem" {
  description = "the tls certificate pem"
}

variable "private_ipv4s" {
  description = "list of private ipv4 for admin network"
  type = "list"
}

variable "public_ipv4s" {
  description = "list of public ipv4"
  type = "list"
}

variable "backup_public_ipv4s" {
  description = "list of backup public ipv4"
  type = "list"
}

variable "backup_private_ipv4s" {
  description = "list of backup public ipv4"
  type = "list"
}

variable "private_port_ids" {
  description = "list of private ipv4 for admin network"
  type = "list"
}

variable "public_port_ids" {
  description = "list of public ids"
  type = "list"
}

variable "vrrp_password" {
  description = "the vrrp password for keepalived"
}

variable "vrrp_router_id" {
  description = "the vrrp router id for keepalived"
}

variable "vrrp_backup_router_id" {
  description = "the vrrp router id for backup addr in keepalived"
}

variable "public_gateway" {
  description = "the network global cidr"
}
