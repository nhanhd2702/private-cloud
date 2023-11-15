#!/bin/bash

# Create neutron config folder
mkdir -R /etc/kolla/config/neutron
# Create ml2_conf.ini
cat << EOF > /etc/kolla/config/neutron/ml2_conf.ini
[ml2]
type_drivers = flat,vlan,vxlan
tenant_network_types = vxlan
mechanism_drivers = openvswitch,l2population
extension_drivers = port_security

[ml2_type_vlan]
network_vlan_ranges = physnet1:1:100
EOF

#Reconfigure neutron service
kolla-ansible -i /etc/kolla/multinode reconfigure -t neutron