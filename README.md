# virtoolization

Collection of tools and scripts to make virtualization easier.

## NAT mode with OVS

Currently Open vSwitch doesn't support libvirt in NAT mode. This script starts 
an OVS bridge, adds NAT rules and starts a dnsmasq instance.

### Installation

Run:
    $ sudo cp ovs-with-nat-mode.sh /usr/local/bin
    $ sudo cp init /etc/init/ovs-nat.conf
    $ sudo cp ovs-nat.conf /etc/default/ovs-nat


### Configuration

All the configuration is stored in the /etc/default/ovs-nat.conf file.

### Using it

Run:
    $ sudo start ovs-nat

You can now plug your virtual machines to the management and data bridges using 
the libvirt bridge mode.
