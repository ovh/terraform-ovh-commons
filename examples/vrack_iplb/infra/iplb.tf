###
### This scripts setups an IPLB in a vrack
###

data ovh_iploadbalancing iplb {
  service_name = var.iplb_id
}

data ovh_iploadbalancing_vrack_networks networks {
  service_name = data.ovh_iploadbalancing.iplb.service_name
  subnet       = var.subnet
  vlan_id      = var.vlan_id
}

resource ovh_iploadbalancing_http_frontend front {
  for_each = toset([for p in var.ports : tostring(p)])

  service_name    = data.ovh_iploadbalancing.iplb.service_name
  display_name    = "${var.name}_${each.value}"
  zone            = "all"
  port            = each.value
  default_farm_id = ovh_iploadbalancing_http_farm.farm[each.value].id
}

resource ovh_iploadbalancing_http_farm farm {
  for_each = toset([for p in var.ports : tostring(p)])

  service_name = data.ovh_iploadbalancing.iplb.service_name
  display_name = "${var.name}_${each.value}"
  zone         = "all"

  probe {
    port     = each.value
    interval = 30
    type     = "tcp"
  }

  vrack_network_id = data.ovh_iploadbalancing_vrack_networks.networks.result[0]
}

locals {
  http_pairs = [
    for pair in setproduct(var.ports, range(var.nodes)) : {
      port = pair[0]
      node = pair[1]
    }
  ]
}

resource ovh_iploadbalancing_http_farm_server backends {
  for_each = {
    for pair in local.http_pairs : "${pair.port}.${pair.node}" => pair
  }

  service_name = data.ovh_iploadbalancing.iplb.service_name
  farm_id      = ovh_iploadbalancing_http_farm.farm[each.value.port].id
  address      = openstack_networking_port_v2.nodes_vrack[each.value.node].all_fixed_ips[0]
  status       = "active"
  probe        = true
  port         = each.value.port
}

resource "ovh_iploadbalancing_refresh" "mylb" {
  service_name = data.ovh_iploadbalancing.iplb.id

  keepers = concat(
    [data.ovh_iploadbalancing_vrack_networks.networks.result[0]],
    [for p in var.ports : ovh_iploadbalancing_http_frontend.front[tostring(p)].id],
    [for p in var.ports : ovh_iploadbalancing_http_farm.farm[tostring(p)].id],
    [for pair in local.http_pairs : ovh_iploadbalancing_http_farm_server.backends["${pair.port}.${pair.node}"].id],
  )
}
