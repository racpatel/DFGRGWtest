rgwcpu=`grep -A4 --no-group-separator 'RGW stats:' $1 |grep -v stats|awk '{sum+=$3};END{print sum/NR}'`
rgwmem=`grep -A4 --no-group-separator 'RGW stats:' $1 |grep -v stats|awk '{sum+=$4};END{print sum/NR}'`
osdcpu=`grep ^ceph-osd $1 |awk '{sum+=$2};END{print sum/NR}'`
osdmem=`grep ^ceph-osd $1 |awk '{sum+=$3};END{print sum/NR}'`
echo -e "$rgwcpu\t$rgwmem\t$osdcpu\t$osdmem"
