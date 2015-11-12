#!/bin/bash

d=$(cd $(dirname $0); echo $PWD)
source $d/nodes.sh
n=0
uuid=${uuids[$n]}
mac=${macs[$n]}

set -x
#zfs create -V 8G tank/mistify/hv$n
truncate -s0 hv$n
qemu-img create -f qcow2 hv$n 8G

qemu-system-x86_64 \
	-kernel $d/bzImage.mistify \
	-initrd $d/initrd.mistify \
	-append "ramdisk_size=$((800*1024)) keepinitrd rw mistify.network=testing mistify.zfs=auto zfs=auto console=ttyS0 mistify.debug/test/not-for-prod.ip=0.0.0.0/24" \
	-nographic \
	-cpu host -smp 2 \
	-machine accel=kvm \
	-global isa-fdc.driveA= \
	-drive if=virtio,file=hv$n,cache=none,format=qcow2 \
	-m 4096 \
	-uuid $uuid \
	-netdev type=tap,id=net0,script=$d/ifup,downscript=$d/ifdown -device e1000,netdev=net0,mac=$mac,id=nic1
