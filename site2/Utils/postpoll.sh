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
#source "$myPath/../Utils/functions-time.shinc"
source "$myPath/../Utils/functions.shinc"

# check for passed arguments
[ $# -ne 2 ] && error_exit "POLL.sh failed - wrong number of args"
[ -z "$1" ] && error_exit "POLL.sh failed - empty first arg"
[ -z "$2" ] && error_exit "POLL.sh failed - empty second arg"

interval=$1          # how long to sleep between polling
log=$2               # the logfile to write to
DATE='date +%Y/%m/%d-%H:%M:%S'

# update log file  
updatelog "** POST POLL started" $log

sample=1
#while [ $SECONDS -lt $postpollend ]; do
while [ true ]; do
    # Sleep for the poll interval before first sample
    sleep "${interval}"

    echo -e "\nSAMPLE (post poll): ${sample}   =============================================\n"
    echo -e "\nSAMPLE (post poll): ${sample}   =============================================\n" >> $log

    # RESHARD activity
    #echo -n "RESHARD: " >> $log
    get_pendingRESHARD
    updatelog "RESHARD Queue Length ${pendingRESHARD}" $log
    updatelog "RESHARD List ${reshardList}" $log
    
    # RGW system Load Average
#    echo "" >> $log
#    echo -n "LA: " >> $log        # prefix line with stats label
#    get_upTime
#    updatelog "${RGWhost} ${upTime}" $log

    # RGW radosgw PROCESS and MEM stats
#    echo -e "\nRGW stats:          proc   %cpu %mem  vsz    rss     memused       memlimit" >> $log        # stats titles
#    for rgw in $RGWhosts1 ; do
#        rgwMem=`ssh $rgw ps -eo comm,pcpu,pmem,vsz,rss | grep -w 'radosgw '` &> /dev/null
#        rgwMemUsed=`ssh $rgw cat /sys/fs/cgroup/memory/memory.usage_in_bytes` &> /dev/null
#        rgwMemLimit=`ssh $rgw cat /sys/fs/cgroup/memory/memory.limit_in_bytes` &> /dev/null
#        echo $rgw"   "$rgwMem"   "$rgwMemUsed"   "$rgwMemLimit >> $log
#    done

    # ceph-osd PROCESS and MEM stats
#    echo -e "\nOSD: " >> $log        # prefix line with stats label
#    for rgw in $RGWhosts1 ; do
#        osdMem=`ssh $rgw ps -eo comm,pcpu,pmem,vsz,rss | grep -w 'ceph-osd '`
#        updatelog "${rgw} ${osdMem}" $log
#    done

# get bucket stats
    get_bucketStats
    #echo -e "\nSite2 buckets (swift):" >> $log
    #echo -e "\nSite2 buckets (swift):"
    #updatelog "${site1bucketsswift}" $log
    echo -e "\nSite2 buckets (rgw):" >> $log
    echo -e "\nSite2 buckets (rgw):"
    updatelog "${site1bucketsrgw}" $log

    if [[ $multisite == "true" ]]; then
        #echo -e "\nSite1 buckets (swift):" >> $log 
        #echo -e "\nSite1 buckets (swift):"
        #updatelog "${site2bucketsswift}" $log
        echo -e "\nSite1 buckets (rgw):" >> $log 
        updatelog "${site2bucketsrgw}" $log
        get_syncStatus
        echo -e "\nSite1 sync status:" >> $log       
        echo -e "\nSite1 sync status:" 
        updatelog "${syncStatus}" $log
        echo -e "\nSite1 buckets sync status:" >> $log
        echo -e "\nSite1 buckets sync status:"
        updatelog "${bucketSyncStatus}" $log
    fi

    if [[ $syncPolling == "true" ]]; then
        # multisite sync status
        site2sync=$(ssh $MONhostname2 /root/syncCntrs.sh)
        echo "" >> $log
        updatelog "site1 sync counters:  ${site2sync}" $log
        get_SyncStats
#        echo -en "\nCeph Client I/O\nsite1: " >> $log
#        updatelog "site1:  ${site1io}" $log
#        echo -n "site2: " >> $log
#        updatelog "site2:  ${site2io}" $log
    fi

    echo -e "\nCluster status" >> $log
    ceph status >> $log

    get_df-detail
    updatelog "ceph df detail ${dfdetail}" $log

    # Record specific pool stats
#    echo -e "\nSite2 pool PG counts:"
#    echo -e "\nSite2 pool PG counts:" >> $log
#    ceph osd pool ls detail >> $log
#    get_buckets_df
#    echo -e "\nSite2 buckets df"
#    echo -e "\nSite2 buckets df" >> $log
#    updatelog "${buckets_df}" $log
#    if [[ $multisite == "true" ]]; then
#        echo -e "\nSite1 buckets df"
#        echo -e "\nSite1 buckets df" >> $log
#        updatelog "${buckets_df2}" $log
#    fi

#    get_free
#    echo -e "\nOSD/RGW free:" >> $log
#    updatelog "${RGWhostname}  ${freemem}" $log

#    get_osddf
#    echo -e "\nCeph osd df:" >> $log
#    updatelog "${osddf}" $log

    # Record the %RAW USED and pending GC count
#    get_rawUsed
##    get_pendingGC
##    echo -en "\nGC: " >> $log
#    updatelog "%RAW USED ${rawUsed}; Pending GCs ${pendingGC}" $log

    # monitor for large omap objs 
#    echo "" >> $log
#    site1omapCount=`ceph health detail |grep 'large obj'`
#    updatelog "Large omap objs (site1): $site1omapCount" $log
#    if [[ $multisite == "true" ]]; then
#        site2omapCount=`ssh $MONhostname2 ceph health detail |grep 'large obj'`
#        updatelog "Large omap objs (site2): $site2omapCount" $log
#    fi

#    echo -e "\nPG Autoscale:" >> $log
#    ceph osd pool autoscale-status >> $log

    sample=$(($sample+1))
done

echo -n "POST POLL.sh: " >> $log   # prefix line with label for parsing
updatelog "** POST POLL ending" $log

