terraform {
  required_version = ">= 0.12.0"
  required_providers {
    openstack = ">= 1.20"
    ovh = ">= 0.6"
    tls = "~> 2.1"
    null = "~> 2.1"
    local = "~> 1.4"
  }
}

provider ovh {
  endpoint = "ovh-eu"
}

provider openstack {
  region = var.region
}

###
# Create the ssh key pair in both openstack & ovh api
###
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# registers private key in ssh-agent
resource null_resource "register_ssh_private_key" {
  triggers = {
    key = base64sha256(tls_private_key.private_key.private_key_pem)
  }

  provisioner "local-exec" {
    command = "echo -n $KEY | base64 -d | ssh-add -"
    environment = {
      KEY = base64encode(tls_private_key.private_key.private_key_pem)
    }
  }
}


# Keypair which will be used on nodes and bastion
resource "openstack_compute_keypair_v2" "keypair" {
  name       = var.name
  public_key = tls_private_key.private_key.public_key_openssh

  depends_on = [null_resource.register_ssh_private_key]
}

resource ovh_me_ssh_key "keypair" {
  key_name = var.name
  key      = trimspace(tls_private_key.private_key.public_key_openssh)

  depends_on = [null_resource.register_ssh_private_key]
}

###
# Network & bastion setup
# The openstack network will host the subnet config and the according dhcp agent
###
module "network" {
  source = "../modules/network"
  name   = var.name
  region = var.region

  remote_ssh_prefixes = var.remote_ssh_prefixes
  ssh_keypair         = openstack_compute_keypair_v2.keypair.name
}

###
# Create cloud vms
###
module "cloudvms-sg" {
  source = "../modules/secgroup"
  name   = var.name
  # dont forget to add docker ip range
  allowed_ingress_prefixes = var.remote_ip_prefixes
  allowed_ingress_tcp      = ["6443"]
  allowed_ssh_sg_ids       = [module.network.bastion_sg_id]
  allowed_sg_ids           = [module.network.bastion_sg_id]
}

module "cloudvms-masters" {
  source             = "../modules/cloudvm-hosts"
  nb                 = var.masters_nb
  name               = "${var.name}-masters"
  subnet_id          = module.network.subnet_id
  secgroup_id        = module.cloudvms-sg.id
  keypair            = openstack_compute_keypair_v2.keypair.name
  assign_floating_ip = true
  bastion_host = module.network.bastion_ipv4
}

module "cloudvms-nodes" {
  source             = "../modules/cloudvm-hosts"
  nb                 = var.cloudvm_nb
  name               = var.name
  subnet_id          = module.network.subnet_id
  secgroup_id        = module.cloudvms-sg.id
  keypair            = openstack_compute_keypair_v2.keypair.name
  assign_floating_ip = true
  bastion_host = module.network.bastion_ipv4
}


module "baremetal" {
  source       = "../modules/baremetal-hosts"
  hosts        = var.baremetal_hosts
  name         = var.name
  os_subnet_id = module.network.subnet_id
  keypair      = openstack_compute_keypair_v2.keypair.name
  bastion_host = module.network.bastion_ipv4
  vlan_id      = var.vlan_id
}

resource local_file inventory_yaml {
  filename = "${path.module}/mycluster/inventory.yaml"
  content  = <<EOF
# ## Configure 'ip' variable to bind kubernetes services on a
# ## different ip than the default iface
# ## We should set etcd_member_name for etcd cluster. The node that is not a etcd member do not need to set the value, or can set the empty string value.
all:
  hosts:
%{for m in module.cloudvms-masters.hosts}
    ${m.name}:
      ansible_host: ${m.vrack_ipv4}
      ip: ${m.vrack_ipv4}
      etcd_member_name: ${m.name}
%{endfor}

%{for m in module.cloudvms-nodes.hosts}
    ${m.name}:
       ansible_host: ${m.vrack_ipv4}
       ip: ${m.vrack_ipv4}
       node_labels:
         openstack-control-plane: enabled
         monitored: enabled
%{endfor}

%{for m in module.baremetal.hosts}
    ${m.name}:
       ansible_host: ${m.vrack_ipv4}
       ip: ${m.vrack_ipv4}
       ansible_user: root
       node_labels:
         openstack-control-plane: enabled
         monitored: enabled
       node_taints:
          - "openstack/db=true:NoSchedule"
%{endfor}

# ## configure a bastion host if your nodes are not directly reachable
bastion:
  hosts:
    bastion:
      ansible_host: ${module.network.bastion_ipv4}
      ansible_user: ubuntu

kube-master:
  hosts:
%{for m in module.cloudvms-masters.hosts}
    ${m.name}:
%{endfor}

etcd:
  hosts:
%{for m in module.cloudvms-masters.hosts}
    ${m.name}:
%{endfor}

kube-node:
  hosts:
%{for m in module.cloudvms-nodes.hosts}
    ${m.name}:
%{endfor}

%{for m in module.baremetal.hosts}
    ${m.name}:
%{endfor}

k8s-cluster:
  children:
    kube-master:
    kube-node:
  vars:
    kubeconfig_localhost: true
    loadbalancer_apiserver:
      address: ${module.cloudvms-masters.public_ipv4_list[0]}
      port: 6443

EOF
}

resource null_resource "kubespray" {
  triggers = {
    inventory  = base64sha256(local_file.inventory_yaml.content)
    playbook   = var.kubespray_playbook
    args       = var.kubespray_args
  }

  provisioner "local-exec" {
    working_dir = path.module
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
    }

    command = <<EOF
if [ ! -d ./kubespray ]; then
   git clone https://github.com/kubernetes-sigs/kubespray
fi
(cd kubespray && sudo pip3 install -r requirements.txt) 
python3 $(which ansible-playbook) -i ${local_file.inventory_yaml.filename} --become --become-user=root kubespray/${var.kubespray_playbook} ${var.kubespray_args}
EOF
  }
}
