vrrp_instance VI_1 {
    interface ens3
    state MASTER
    priority 200

    virtual_router_id ${virtual_router_id_master}
    unicast_src_ip ${private_ip}

    unicast_peer {
       ${private_peer_ip}
    }

    virtual_ipaddress {
       ${virtual_ip_master}/28 dev ens4
    }

    virtual_routes {
       src ${virtual_ip_master} to 0.0.0.0/0 via ${gateway} dev ens4
    }

    authentication {
        auth_type PASS
        auth_pass ${auth_password}
    }

    notify_master /etc/keepalived/haproxy_reload.sh

}

vrrp_instance VI_2 {
    interface ens3
    state BACKUP
    priority 100

    virtual_router_id ${virtual_router_id_backup}
    unicast_src_ip ${private_ip}

    unicast_peer {
       ${private_peer_ip}
    }

    virtual_ipaddress {
       ${virtual_ip_backup}/28 dev ens4
    }

    virtual_routes {
       src ${virtual_ip_backup} to 0.0.0.0/0 via ${gateway} dev ens4
    }

    authentication {
        auth_type PASS
        auth_pass ${auth_password}
    }

    notify_master /etc/keepalived/haproxy_reload.sh

}