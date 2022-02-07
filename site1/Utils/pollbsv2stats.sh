#!/bin/bash
#
# pollbsv2stats.sh
#   Polls Bluestore-V2 perf stats 
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
[ $# -ne 2 ] && error_exit "pollbsv2stats.sh failed - wrong number of args"
[ -z "$1" ] && error_exit "pollbsv2stats.sh failed - empty first arg"
[ -z "$2" ] && error_exit "pollbsv2stats.sh failed - empty second arg"
#[ -z "$3" ] && error_exit "pollbsv2stats.sh failed - empty third arg"

interval=$1          # how long to sleep between polling
#perfdumps=$2         # the osd perf dump log 
#mempools=$3          # the osd dump_mempools log 
#bsdumps=$4           # the bluestore allocator dump block log 
#DATE='date +%Y/%m/%d-%H:%M:%S'
DATE=$2
sample=1
fsid=`ceph status |grep id: |awk '{print$2}'`

if [[ $cephadmshell == "true" ]]; then
    basepath=/rootfs${PWD}
else
    basepath=${PWD}
fi

#BSDUMPS="${RESULTSDIR}/${PROGNAME}_BSdumps_${ts}.log

###########################################################
# keep polling until cluster reaches 'threshold' % fill mark
threshold="75.0"
get_rawUsed
#while (( $(awk 'BEGIN {print ("'$rawUsed'" < "'$threshold'")}') )); do
while (( $(echo "${rawUsed} < ${threshold}" | bc -l) )); do

    # osd bluestore allocator score & block dump
#    for i in `cat ~/rgws.list` ; do    # RHCS 4
#        osd=`ssh $i "ls -d /var/lib/ceph/osd/ceph-* |head -1|cut -d\- -f2"`
#        echo -e "\n\nSAMPLE ${sample}  `date +%Y/%m/%d-%H:%M:%S` =============================================\n" >> ${basepath}/RESULTS/osd.${osd}_bsdumps_${DATE}.log
#	ssh $i "ceph daemon osd.$osd bluestore allocator score bluefs-db ; ceph daemon osd.$osd bluestore allocator dump block" >> ${basepath}/RESULTS/osd.${osd}_bsdumps_${DATE}.log
#    done


    # rgw perf dump	# RHCS 5
#    echo -e "\n\nSAMPLE ${sample}  `date +%Y/%m/%d-%H:%M:%S` =============================================\n" >> ${basepath}/RESULTS/rgw-perfdump_${DATE}.log
#    ssh $RGWhostname "cd /var/run/ceph/$fsid && ceph --admin-daemon ceph-client.rgw.rgws.*.asok perf dump" >> ${basepath}/RESULTS/rgw-perfdump_${DATE}.log

    for i in `seq 0 191` ; do     # RHCS 5
	# osd perf dump
        echo -e "\n\nSAMPLE ${sample} `date +%Y/%m/%d-%H:%M:%S`  =============================================\n" >> ${basepath}/RESULTS/osd.${i}_perfDumps_${DATE}.log
        host=`ceph osd find $i |grep host|tail -1|cut -d\" -f4`
        ceph tell osd.${i} perf dump >> ${basepath}/RESULTS/osd.${i}_perfDumps_${DATE}.log

        # osd dump_mempools
        echo -e "\n\nSAMPLE ${sample}  `date +%Y/%m/%d-%H:%M:%S` =============================================\n" >> ${basepath}/RESULTS/osd.${i}_mempools_${DATE}.log
        host=`ceph osd find $i |grep host|tail -1|cut -d\" -f4`
        ceph tell osd.${i} dump_mempools >> ${basepath}/RESULTS/osd.${i}_mempools_${DATE}.log


#        echo -e "\n\nSAMPLE ${sample} `date +%Y/%m/%d-%H:%M:%S`  =============================================\n" >> ${basepath}/RESULTS/osd.${i}_perfDumps_${DATE}.log
#        host=`ceph osd find $i |grep host|tail -1|cut -d\" -f4`
#        ssh $host "ceph daemon osd.${i} perf dump" >> ${basepath}/RESULTS/osd.${i}_perfDumps_${DATE}.log

	# osd dump_mempools
#        echo -e "\n\nSAMPLE ${sample}  `date +%Y/%m/%d-%H:%M:%S` =============================================\n" >> ${basepath}/RESULTS/osd.${i}_mempools_${DATE}.log
#        host=`ceph osd find $i |grep host|tail -1|cut -d\" -f4`
#        ssh $host "ceph daemon osd.${i} dump_mempools" >> ${basepath}/RESULTS/osd.${i}_mempools_${DATE}.log

	# osd bluestore allocator score & block dump
#        echo -e "\n\nSAMPLE ${sample}  `date +%Y/%m/%d-%H:%M:%S` =============================================\n" >> ${basepath}/RESULTS/osd.${i}_bsdumps_${DATE}.log
#        host=`ceph osd find $i |grep host|tail -1|cut -d\" -f4`
#        ssh $host "ceph daemon osd.${i} bluestore allocator score bluefs-db" >> ${basepath}/RESULTS/osd.${i}_bsdumps_${DATE}.log
#        echo "" >> osd.${i}_bsdumps_${DATE}.log
#        ssh $host "ceph daemon osd.${i} bluestore allocator dump block" >> ${basepath}/RESULTS/osd.${i}_bsdumps_${DATE}.log
    done

    # Sleep for the poll interval
    sleep "${interval}"

    sample=$(($sample+1))
done

echo -n "pollbsv2stats.sh: " >> $log   # prefix line with label for parsing
updatelog "** 75% fill mark hit: POLL ending" $log

#echo " " | mail -s "pollbsv2stats.sh fill mark hit - terminated" user@company.net

# DONE
