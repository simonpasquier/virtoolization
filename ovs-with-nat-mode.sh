#!/bin/bash
# Setup the Open vSwitch for running a local lab (based on libvirt/KVM) 
# behind NAT
set -e
if [[ -n "${DEBUG}" ]]; then
    set -x
fi

if [ $(id -u) != "0" ]; then
    echo $(id -u)
    echo "Must be run as root"
    exit 1
fi
DNSMASQ_BIN=$(which dnsmasq)
if [ -z "${DNSMASQ_BIN}" ]; then
    echo "dnsmasq should be installed"
    exit 1
fi

# Get user-configuration
if [ -e /etc/default/ovs-nat.conf ]; then
    source /etc/default/ovs-nat.conf
fi

# WAN_INTERFACE connects the OVS switch to the external network
WAN_INTERFACE=${WAN_INTERFACE:-em1}
# MGMT_BRIDGE is the management network for the nodes
MGMT_BRIDGE=${MGMT_BRIDGE:-br-mgmt}
MGMT_BRIDGE_IP=${MGMT_BRIDGE_IP:-192.168.1.1}
MGMT_BRIDGE_CIDR=${MGMT_BRIDGE_IP}/24
# IPs available for the vNICs connected to the management
MGMT_DHCP_RANGE=${MGMT_DHCP_RANGE:-192.168.1.2,192.168.1.254}
# DATA_BRIDGE is the data network for the nodes
DATA_BRIDGE=${DATA_BRIDGE:-br-int}

ovs-vsctl br-exists ${MGMT_BRIDGE} && ovs-vsctl del-br ${MGMT_BRIDGE} || true
ovs-vsctl br-exists ${DATA_BRIDGE} && ovs-vsctl del-br ${DATA_BRIDGE} || true

ovs-vsctl add-br ${MGMT_BRIDGE}
ovs-vsctl add-br ${DATA_BRIDGE}

ip addr add ${MGMT_BRIDGE_CIDR} dev ${MGMT_BRIDGE}
ip link set dev ${MGMT_BRIDGE} up
ip link set dev ${DATA_BRIDGE} up

# Setup firewall rules if missing
if [[ -z "$(iptables -t filter -S INPUT | grep ${MGMT_BRIDGE})" ]]; then
    sh -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'

    # TODO: be less permissive on firewall rules
    iptables -t filter -P INPUT ACCEPT
    iptables -t filter -P FORWARD ACCEPT
    iptables -t filter -P OUTPUT ACCEPT
    iptables -t filter -A FORWARD -i ${WAN_INTERFACE} -o ${MGMT_BRIDGE} -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -t filter -A FORWARD -i ${MGMT_BRIDGE} -o ${WAN_INTERFACE} -j ACCEPT

    iptables -t nat -P PREROUTING ACCEPT
    iptables -t nat -P INPUT ACCEPT
    iptables -t nat -P OUTPUT ACCEPT
    iptables -t nat -P POSTROUTING ACCEPT
    iptables -t nat -A POSTROUTING -o ${WAN_INTERFACE} -j MASQUERADE
fi

# Start dnsmasq on the management network
DNSMASQ_PID=/tmp/dnsmasq.${MGMT_BRIDGE}.pid
if [ -r ${DNSMASQ_PID} ]; then
    kill $(cat ${DNSMASQ_PID}) || true
    rm ${DNSMASQ_PID}
fi
${DNSMASQ_BIN} --strict-order --except-interface lo --listen-address ${MGMT_BRIDGE_IP} \
 --dhcp-range ${MGMT_DHCP_RANGE},120 --dhcp-leasefile=/tmp/dnsmasq.${MGMT_BRIDGE}.leases \
 --dhcp-lease-max=253 --dhcp-no-override --pid=${DNSMASQ_PID}

