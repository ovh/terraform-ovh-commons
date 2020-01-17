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

data ovh_dedicated_server "server" {
  for_each     = var.dedicated_servers_ids
  service_name = each.key
}

resource ovh_vrack_dedicated_server_interface "vdsi" {
  for_each     = var.dedicated_servers_ids

  vrack_id     = var.vrack_id
  interface_id = [for i in data.ovh_dedicated_server.server[each.key].vnis : i.uuid if i.mode == "vrack"][0]
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
