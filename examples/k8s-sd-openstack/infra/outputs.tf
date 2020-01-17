output bastion_ipv4 {
  value = module.network.bastion_ipv4
}


output "ssh_public_key" {
  description = "SSH public key"
  sensitive   = true
  value       = tls_private_key.private_key.public_key_openssh
}

output "ssh_private_key" {
  description = "SSH private key"
  sensitive   = true
  value       = tls_private_key.private_key.private_key_pem
}

# output "vm_public_ips" {
#   value = module.cloudvms.public_ipv4_list
# }

# output "vm_private_ips" {
#   value = module.cloudvms.vrack_ipv4_list
# }

# output "bm_public_ips" {
#   value = module.baremetal.public_ipv4_list
# }

# output "bm_private_ips" {
#   value = module.baremetal.vrack_ipv4_list
# }

# output "all_private_ips" {
#   value = concat(module.baremetal.vrack_ipv4_list, module.cloudvms.vrack_ipv4_list)
# }
