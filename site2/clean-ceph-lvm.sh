#!/bin/bash
lvs=`lvscan | grep ceph | awk '{ print $2 }' | sed "s/'//g"`
vgs=`vgscan | grep ceph | awk '{print $4}' | tr '"' ' '`
pvs=`pvscan | grep ceph | awk '{print $2}'`

for l in $lvs ; do
	lvremove -y $l
done

for v in $vgs ; do
	vgremove -y $v
done

for p in $pvs ; do
	pvremove $p
done
