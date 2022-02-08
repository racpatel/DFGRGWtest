#!/bin/bash
#
# POLL.sh
#   Polls ceph and logs stats and writes to LOGFILE
#

# Bring in other script files
myPath="${BASH_SOURCE%/*}"
if [[ ! -d "$myPath" ]]; then
    myPath="$PWD"
fi

# Variables
source "$myPath/../vars.shinc"

# Functions
# defines: 'get_' routines
source "$myPath/../Utils/functions.shinc"

# check for passed arguments
[ $# -ne 2 ] && error_exit "POLL.sh failed - wrong number of args"
[ -z "$1" ] && error_exit "POLL.sh failed - empty first arg"
[ -z "$2" ] && error_exit "POLL.sh failed - empty second arg"

interval=$1          # how long to sleep between polling
log=$2               # the logfile to write to
DATE='date +%Y/%m/%d-%H:%M:%S'

# update log file  
updatelog "** POLL started" $log

###########################################################
echo -e "\nceph balancer status" >> $log
ceph balancer status >> $log

# log current RGW/OSD tunings
get_tuning
updatelog "OSD Settings:  ${osdtuning}" $log
updatelog "RGW Settings:  ${rgwtuning}" $log

# verify necessary 5.0 changes
echo -e "\nTCMALLOC checks:" >> $log
if [[ $cephadmshell == "true" ]]; then
    ansible -i /rootfs/etc/ansible -m shell -a '/root/check-osd-hacks.sh' osds >> $log
    ansible -i /rootfs/etc/ansible -m shell -a '/root/check-mon-hacks.sh' mons >> $log
else
    ansible -i /etc/ansible -m shell -a '/root/check-osd-hacks.sh' osds >> $log
    ansible -i /etc/ansible -m shell -a '/root/check-mon-hacks.sh' mons >> $log
fi

# collect daemon diffs
case $CEPHVER in
  luminous)
    ssh $RGWhostname 'ceph daemon `ls /var/run/ceph/ceph-osd.*.asok|head -1` config diff' > $OSDDIFF
    ssh $RGWhostname 'ceph daemon `ls /var/run/ceph/ceph-client.rgw.*.asok|tail -1` config diff' > $RGWDIFF
    ssh $MONhostname 'ceph daemon `ls /var/run/ceph/ceph-mgr.*.asok|head -1` config diff' > $MGRDIFF
    ssh $MONhostname 'ceph daemon `ls /var/run/ceph/ceph-mon.*.asok|head -1` config diff' > $MONDIFF
    ;;
  nautilus)
    ssh $RGWhostname 'ceph daemon `ls /var/run/ceph/ceph-osd.*.asok|head -1` config diff' > $OSDDIFF
    ssh $RGWhostname 'ceph daemon `ls /var/run/ceph/ceph-client.rgw.*.asok|tail -1` config diff' > $RGWDIFF
    ssh $MONhostname 'ceph daemon `ls /var/run/ceph/ceph-mgr.*.asok|head -1` config diff' > $MGRDIFF
    ssh $MONhostname 'ceph daemon `ls /var/run/ceph/ceph-mon.*.asok|head -1` config diff' > $MONDIFF
    ;;
  pacific)
    fsid=`ceph status |grep id: |awk '{print$2}'`
    osd=`ceph osd tree|grep hdd |head -1|awk '{print$1}'`
    ssh $RGWhostname "cd /var/run/ceph/$fsid && ceph --admin-daemon ceph-client.rgw.rgws.*.asok config diff"  > $RGWDIFF
    ssh $RGWhostname "cd /var/run/ceph/$fsid && ceph --admin-daemon ceph-osd.${osd}.asok config diff" > $OSDDIFF
    ssh $MONhostname "cd /var/run/ceph/$fsid && ceph --admin-daemon ceph-mgr.*.asok config diff"  > $MGRDIFF
    ssh $MONhostname "cd /var/run/ceph/$fsid && ceph --admin-daemon ceph-mon.*.asok config diff"  > $MONDIFF
    ;;
  quincy)
    fsid=`ceph status |grep id: |awk '{print$2}'`
    osd=`ceph osd tree|grep hdd |head -1|awk '{print$1}'`
    ssh $RGWhostname "cd /var/run/ceph/$fsid && ceph --admin-daemon ceph-client.rgw.rgws.*.asok config diff"  > $RGWDIFF
    ssh $RGWhostname "cd /var/run/ceph/$fsid && ceph --admin-daemon ceph-osd.${osd}.asok config diff" > $OSDDIFF
    ssh $MONhostname "cd /var/run/ceph/$fsid && ceph --admin-daemon ceph-mgr.*.asok config diff"  > $MGRDIFF
    ssh $MONhostname "cd /var/run/ceph/$fsid && ceph --admin-daemon ceph-mon.*.asok config diff"  > $MONDIFF
    ;;
  *)
    echo "unable to gather daemon config diffs stats, exit..."
    ;;
esac

echo -e "\nOSD swapon -s ..." >> $log
if [[ $cephadmshell == "true" ]]; then
    ansible -i /rootfs/etc/ansible -o -m command -a "swapon -s" osds >> $log
else
    ansible -i /etc/ansible -o -m command -a "swapon -s" osds >> $log
fi

# add %RAW USED and GC status to LOGFILE
#get_pendingGC   # this call can be expensive
#echo -en "\nGC: " >> $log   # prefix line with GC label for parsing
get_rawUsed
echo "" >> $log
updatelog "%RAW USED ${rawUsed}; Pending GCs ${pendingGC}" $log
threshold="80.0"

# reset site2 sync counters
if [[ $multisite == "true" ]]; then
    if [[ $syncPolling == "true" ]]; then
	echo "" >> $log
        updatelog "Resetting data-sync-from-site1 counters on site2 RGWs" $log
	case $CEPHVER in
            luminous)
                for rgw in $RGWhosts2 ; do
                    ssh ${rgw} 'ceph daemon `ls /var/run/ceph/ceph-client.rgw*.asok|tail -1` perf reset data-sync-from-site1' >> $log
                done
	        ;;
            nautilus)
                for rgw in $RGWhosts2 ; do
                    ssh ${rgw} 'ceph daemon `ls /var/run/ceph/ceph-client.rgw*.asok|tail -1` perf reset data-sync-from-site1' >> $log
                done
	        ;;
	    pacific)
                fsid2=`ssh $RGWhostname2 "ceph status |grep id:" |awk '{print$2}'`
                for rgw in $RGWhosts2 ; do
                    ssh ${rgw} "cd /var/run/ceph/$fsid2 && ceph --admin-daemon ceph-client.rgw.rgws.*.asok perf reset data-sync-from-site1"
                done
	        ;;
	    quincy)
                fsid2=`ssh $RGWhostname2 "ceph status |grep id:" |awk '{print$2}'`
                for rgw in $RGWhosts2 ; do
                    ssh ${rgw} "cd /var/run/ceph/$fsid2 && ceph --admin-daemon ceph-client.rgw.rgws.*.asok perf reset data-sync-from-site1"
                done
	        ;;
	    *)
                echo "unable to reset site2 sync counters, exit..."
                ;;
        esac
    fi
fi

# keep polling until cluster reaches 'threshold' % fill mark
#while (( $(awk 'BEGIN {print ("'$rawUsed'" < "'$threshold'")}') )); do
#while [ true ]; do
while (( $(echo "${rawUsed} < ${threshold}" | bc -l) )); do
    echo -e "\n--------------------------------------------------------\n" >> $log
    # RESHARD activity
    #echo -n "RESHARD: " >> $log
    get_pendingRESHARD
    updatelog "RESHARD Queue Length ${pendingRESHARD}" $log
    updatelog "RESHARD List ${reshardList}" $log
    
    # RGW system Load Average
    echo "" >> $log
    echo -n "LA: " >> $log        # prefix line with stats label
    get_upTime
    updatelog "${RGWhost} ${upTime}" $log

#    get_rgwMem
#    updatelog "${RGWhostname} ${rgwMem} ${rgwMemUsed}" $log

    # RGW radosgw PROCESS and MEM stats
    echo -e "\nRGW stats:          proc   %cpu %mem  vsz    rss     memused       memlimit" >> $log        # stats titles
    for rgw in $RGWhosts1 ; do
        rgwMem=`ssh $rgw ps -eo comm,pcpu,pmem,vsz,rss | grep -w 'radosgw '` &> /dev/null
        rgwMemUsed=`ssh $rgw cat /sys/fs/cgroup/memory/memory.usage_in_bytes` &> /dev/null
        rgwMemLimit=`ssh $rgw cat /sys/fs/cgroup/memory/memory.limit_in_bytes` &> /dev/null
        echo $rgw"   "$rgwMem"   "$rgwMemUsed"   "$rgwMemLimit >> $log
    done

    # ceph-osd PROCESS and MEM stats
    echo -e "\nOSD: " >> $log        # prefix line with stats label
#    get_osdMem
#    updatelog "${RGWhostname} ${osdMem}" $log
#    updatelog "${RGWhostname2} ${osdMem2}" $log
    for rgw in $RGWhosts1 ; do
        osdMem=`ssh $rgw ps -eo comm,pcpu,pmem,vsz,rss | grep -w 'ceph-osd '`
        updatelog "${rgw} ${osdMem}" $log
    done

    # ceph client stats
#    get_clientStats
#    echo -en "\nCeph Client I/O\nsite1: " >> $log
#    updatelog "site1 client IO:  ${site1client}" $log
#    echo -n "site2: " >> $log
#    updatelog "site2 client IO:  ${site2client}" $log
#    echo "" >> $log

# get bucket stats
    get_bucketStats
    #echo -e "\nSite1 buckets (swift):" >> $log
    #echo -e "\nSite1 buckets (swift):"
    #updatelog "${site1bucketsswift}" $log
    echo -e "\nSite1 buckets (rgw):" >> $log
    echo -e "\nSite1 buckets (rgw):"
    updatelog "${site1bucketsrgw}" $log

    if [[ $multisite == "true" ]]; then
        #echo -e "\nSite2 buckets (swift):" >> $log 
        #echo -e "\nSite2 buckets (swift):"
        #updatelog "${site2bucketsswift}" $log
        echo -e "\nSite2 buckets (rgw):" >> $log 
        updatelog "${site2bucketsrgw}" $log
        get_syncStatus
        echo -e "\nSite2 sync status:" >> $log       
        echo -e "\nSite2 sync status:" 
        updatelog "${syncStatus}" $log
        echo -e "\nSite2 buckets sync status:" >> $log
        echo -e "\nSite2 buckets sync status:"
        updatelog "${bucketSyncStatus}" $log
    fi

    if [[ $syncPolling == "true" ]]; then
        # multisite sync status
        site2sync=$(ssh $MONhostname2 /root/syncCntrs.sh)
        echo "" >> $log
        updatelog "site2 sync counters:  ${site2sync}" $log
#        cmdStart=$SECONDS
#        get_dataLog
#        dataLog_duration=$(($SECONDS - $cmdStart))
#        echo -e "\nsite1 data log list ---------------------------------------------------- " >> $DATALOG
#        echo "dataLog response time: $dataLog_duration" >> $DATALOG
#        updatelog "${dataLog}" $DATALOG
        get_SyncStats
        echo -en "\nCeph Client I/O\nsite1: " >> $log
        updatelog "site1:  ${site1io}" $log
        echo -n "site2: " >> $log
        updatelog "site2:  ${site2io}" $log
    fi

    echo -e "\nCluster status" >> $log
    ceph status >> $log

    get_df-detail
    updatelog "ceph df detail ${dfdetail}" $log

    # Record specific pool stats
#    echo -e "\nSite1 pool PG counts:" >> $log
#    for i in `rados lspools` ; do echo -ne $i"\t" >> $log ; ceph osd pool get $i pg_num >> $log ; done
    echo -e "\nSite1 pool PG counts:"
    echo -e "\nSite1 pool PG counts:" >> $log
    ceph osd pool ls detail >> $log
    get_buckets_df
    echo -e "\nSite1 buckets df"
    echo -e "\nSite1 buckets df" >> $log
    updatelog "${buckets_df}" $log
    if [[ $multisite == "true" ]]; then
        echo -e "\nSite2 buckets df"
        echo -e "\nSite2 buckets df" >> $log
        updatelog "${buckets_df2}" $log
    fi

    get_free
    echo -e "\nOSD/RGW free:" >> $log
    updatelog "${RGWhostname}  ${freemem}" $log

    get_osddf
    echo -e "\nCeph osd df:" >> $log
    updatelog "${osddf}" $log

    # Record the %RAW USED and pending GC count
# NOTE: this may need to be $7 rather than $4 <<<<<<<<
    get_rawUsed
#    get_pendingGC
#    echo -en "\nGC: " >> $log
    updatelog "%RAW USED ${rawUsed}; Pending GCs ${pendingGC}" $log

    # monitor for large omap objs 
#    echo "" >> $log
#    site1omapCount=`ceph health detail |grep 'large obj'`
#    updatelog "Large omap objs (site1): $site1omapCount" $log
#    if [[ $multisite == "true" ]]; then
#        site2omapCount=`ssh $MONhostname2 ceph health detail |grep 'large obj'`
#        updatelog "Large omap objs (site2): $site2omapCount" $log
#    fi

    echo -e "\nPG Autoscale:" >> $log
    ceph osd pool autoscale-status >> $log

    # osd_memory_targets
#    echo -e "\nosd_memory_targets(ceph config):" >> $log
#    for i in `seq 0 191` ; do     # RHCS 5
#        echo -n "osd.${i}:  " >> $log
#        ceph config get osd.$i osd_memory_target >> $log
#    done

    # Sleep for the poll interval
    sleep "${interval}"
done

# verify any rgw lifecycle policies ... &&& one-off testing, remove later
#echo -e "\nCheck buckets for LC policies ..." >> $log
#for i in `seq 6` ; do echo mycontainers$i >> $log ; s3cmd getlifecycle s3://mycontainers$i >> $log ; done

echo -n "POLL.sh: " >> $log   # prefix line with label for parsing
updatelog "** ${threshold}% fill mark hit: POLL ending" $log

#echo " " | mail -s "POLL fill mark hit - terminated" user@company.net

# DONE
