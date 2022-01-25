#!/usr/bin/env python3
 
import sys
import pylxd
import random
import string
import urllib
import subprocess
import re
import os
import netifaces

if len(sys.argv) != 2:
    print("Usage:",sys.argv[0],"<test-bed name>")
    sys.exit(1)

if os.geteuid() != 0:
    print("You need root permissions to set-up your test-bed")
    sys.exit(1)

# Name of the test-bed
NAME = sys.argv[1]
 
# Create a lxd_client
lxd_client = pylxd.Client()
 
# Procedure for adding flow into ovs bridge
def addFlow(bridge, in_port, out_port, bidirectional=True):
    out = subprocess.run(['ovs-ofctl', 'add-flow', str(bridge), 'priority=10,in_port='+str(in_port)+',actions=output:'+out_port])
    if bidirectional:
        out = subprocess.run(['ovs-ofctl', 'add-flow', str(bridge), 'priority=10,in_port='+str(out_port)+',actions=output:'+in_port])

######################################################################
# NETWORK
######################################################################
# Create a new OVS bridge for this tb
try:
    lxd_client.networks.get(NAME)
    print("Network {} already exists. Exiting...".format(NAME))
    sys.exit(1)
except pylxd.exceptions.NotFound as e:
    pass
network = lxd_client.networks.create(NAME, description='tb network', type='bridge', config={'bridge.driver': 'openvswitch'})
# Delete flows from the bridge - they will be added later
out = subprocess.run(['ovs-ofctl', 'del-flows', NAME])
out = subprocess.run(['ovs-ofctl', 'add-flow', NAME, 'priority=0,actions=drop'])
print("Done with creating network {}".format(NAME))
 
######################################################################
# STORAGE POOL
######################################################################
# Create a storage pool for this tb
try:
    lxd_client.storage_pools.get(NAME)
    print("Storage pool {} already exists. Exiting...".format(NAME))
    sys.exit(1)
except pylxd.exceptions.NotFound as e:
    pass
storage_pool = lxd_client.storage_pools.create({"config": {"size": "15GB"}, "driver": "btrfs", "name": NAME})
print("Done with creating storage pool {}".format(NAME))

######################################################################
# CREATE PROFILES
######################################################################
# Create a profile with two interfaces on the switches
try:
    lxd_client.profiles.get(NAME)
    print("Profile {} already exists. Exiting....".format(NAME))
    sys.exit(1)
except pylxd.exceptions.NotFound as e:
    pass
profile = lxd_client.profiles.create(NAME,
        devices={
	    'root': {'path': '/', 'pool': NAME, 'type': 'disk'},
            'eth0': {'name': 'eth0', 'nictype': 'bridged', 'parent': NAME, 'type': 'nic'},
            'eth1': {'name': 'eth1', 'nictype': 'bridged', 'parent': NAME, 'type': 'nic'},
        })
print("Done with creating profile {}".format(NAME))

######################################################################
# CREATE IMAGES
######################################################################
try:
    lxd_client.images.get_by_alias(NAME)
    print("Image {} already exists. Exiting...".format(NAME))
    sys.exit(1)
except pylxd.exceptions.NotFound as e:
    pass
with open('frr.tar.gz', 'rb') as f:
    image_data = f.read()
with open('frr_metadata.tar.gz', 'rb') as f:
    metadata = f.read()
try:
    image = lxd_client.images.create(image_data, metadata=metadata, public=False, wait=True)
    image.add_alias(NAME, "TRex image")
except pylxd.exceptions.LXDAPIException as e:
    print(e)
    sys.exit(1)
print("Done with creating image {}".format(NAME))

######################################################################
# CREATE CONTAINERS
######################################################################
for c_id in range(4):
    container_name = NAME+'-'+str(c_id)
    try:
        lxd_client.containers.get(container_name)
        print("Container {} already exists. Exiting...".format(container_name))
        sys.exit(1)
    except pylxd.exceptions.NotFound as e:
        pass

    config = {'name': container_name,
              'source': {'type': 'image', 'alias': NAME},
              'public': False,
              'auto_update': False,
              'profiles': ['default', NAME] }
    cont = lxd_client.containers.create(config, wait=True)
    cont.start(wait=True)
    print("Container #"+str(c_id)+" started")

######################################################################
# NETWORKING
######################################################################
print("Setting up networking...", end="")
# Set-up networking
host_ifaces = {}
for iface in netifaces.interfaces():
    # Read ifindex and iflink
    with open('/sys/class/net/'+iface+'/ifindex', 'r') as f:
        ifindex = int(f.read().strip())
    with open('/sys/class/net/'+iface+'/iflink', 'r') as f:
        iflink = int(f.read().strip())
    host_ifaces[ifindex] = {'name': iface, 'peer_id': iflink}

# Get ifaces from the containers
ifaces = {}
ifaces_map = {}
try:
    for c_id in range(4):
        container_name = NAME+'-'+str(c_id)
        cont = lxd_client.containers.get(container_name)
        cont_profiles = [lxd_client.profiles.get(p) for p in cont.profiles]
        nics = set([k for p in cont_profiles for k in p.devices if p.devices[k]['type'] == 'nic'])
 
        cont_ifaces = {}
        # Read ifindex and iflink
        for iface in nics:
            ifindex = int(cont.execute(['cat', '/sys/class/net/'+iface+'/ifindex']).stdout.strip())
            iflink = int(cont.execute(['cat', '/sys/class/net/'+iface+'/iflink']).stdout.strip())
            cont_ifaces[ifindex] = {'name': iface, 'peer_id': iflink}
        ifaces[container_name] = cont_ifaces
        ifaces_map[container_name] = {}

except Exception as e:
    print(e)
    sys.exit(1)

# Create the mapping
for c_id in range(4):
    container_name = NAME+'-'+str(c_id)
    cont_ifaces = ifaces[container_name]
    for iface in cont_ifaces:
        iface_name = cont_ifaces[iface]['name']
        peer_id = cont_ifaces[iface]['peer_id']
        ifaces_map[container_name][iface_name] = host_ifaces[peer_id]['name']

# Connect ifaces by means of ovs flows
addFlow(NAME, ifaces_map[NAME+'-0']['eth0'], ifaces_map[NAME+'-1']['eth0'])
addFlow(NAME, ifaces_map[NAME+'-0']['eth1'], ifaces_map[NAME+'-2']['eth0'])
addFlow(NAME, ifaces_map[NAME+'-1']['eth1'], ifaces_map[NAME+'-3']['eth0'])
addFlow(NAME, ifaces_map[NAME+'-2']['eth1'], ifaces_map[NAME+'-3']['eth1'])
print("Done")

print("==========================================================")
print(" All done. Have fun!")
print("==========================================================")

# exit
sys.exit(0)
