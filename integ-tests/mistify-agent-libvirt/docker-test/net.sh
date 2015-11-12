#!/bin/bash

ip=$(ip addr show dev eth0 | awk '/inet / {print $2}')
route=$(ip route | awk '/default via/ {print $3}')

ifconfig eth0 0
ovs-vsctl add-br mistify0
ovs-vsctl add-port mistify0 eth0
ip link set mistify0 up
ip addr add $ip dev mistify0
ip route add default via $route
