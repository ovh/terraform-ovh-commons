variable "name" {
  type = string
}

variable "network_cidr" {
  type = string
}

variable "subnet_cidr" {
  type = string
}

variable "vlan_id" {
  type = number
}

variable "nb_hosts" {
  type = number
}

variable "image_name" {
  type = string
}

variable "flavor_name" {
  type = string
}

variable "ssh_public_key" {
  type = string
}
