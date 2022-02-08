#!/bin/bash
#
# omapkeys.sh
#   gets omap key counts & writes to file
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
[ $# -ne 2 ] && error_exit "omapkeys.sh failed - wrong number of args"
[ -z "$1" ] && error_exit "omapkeys.sh failed - empty first arg"
[ -z "$2" ] && error_exit "omapkeys.sh failed - empty second arg"

interval=$1          # how long to sleep between polling
log=$2               # the logfile to write to

updatelog "** OMAP KEY COUNTS started" >> $log
while true; do
    ts=`date +%Y/%m/%d-%H:%M:%S`
    # update log file  
    echo -e "$ts  =============================================\n" >> $log
    omapCount=`ceph status |grep omap |awk '{print$1}'`
    echo "Large omap objs:  $omapCount" >> $log
    get_omapKeys
    echo -e "index shard omap keys\n${index_log}\n" >> $log
    echo -e "data_log shard omap keys\n${data_log}\n" >> $log
    echo -e "meta_log shard omap keys\n${meta_log}\n" >> $log
    sleep $interval
done
updatelog "** OMAP KEY COUNTS ending" >> $log

