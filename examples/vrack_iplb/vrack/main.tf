terraform {
  required_version = ">= 0.12.0"
  required_providers {
    openstack = ">= 1.20"
    ovh = ">= 0.6"
  }
}

provider ovh {
  endpoint = "ovh-eu"
}

provider openstack {
  region = var.region
}

###
### this scripts setups the vrack network
###
data openstack_identity_auth_scope_v3 os {
  name = var.name
}

data ovh_iploadbalancing iplb {
  service_name = var.iplb_id
}

resource ovh_vrack_cloudproject vrack_openstack {
  vrack_id   = var.vrack_id
  project_id = data.openstack_identity_auth_scope_v3.os.project_id
}

resource ovh_cloud_network_private vrack {
  project_id = ovh_vrack_cloudproject.vrack_openstack.project_id
  name       = var.name
  regions    = [var.region]
  vlan_id    = var.vlan_id
}

resource ovh_vrack_iploadbalancing vrack_iplb {
  service_name     = var.vrack_id
  ip_loadbalancing = data.ovh_iploadbalancing.iplb.service_name
}

resource ovh_iploadbalancing_vrack_network network {
  service_name = ovh_vrack_iploadbalancing.vrack_iplb.ip_loadbalancing
  subnet       = var.subnet
  vlan         = var.vlan_id
  nat_ip       = var.subnet_iplb
  display_name = var.name
}
