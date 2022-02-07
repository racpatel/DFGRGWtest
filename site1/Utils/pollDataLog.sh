#!/bin/bash
#
# POLLdatalog.sh
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
[ $# -ne 2 ] && error_exit "POLLdatalog.sh failed - wrong number of args"
[ -z "$1" ] && error_exit "POLLdatalog.sh failed - empty first arg"
[ -z "$2" ] && error_exit "POLLdatalog.sh failed - empty second arg"

interval=$1          # how long to sleep between polling
log=$2               # the logfile to write to
DATE='date +%Y/%m/%d-%H:%M:%S'

###########################################################
# keep polling until cluster reaches 'threshold' % fill mark
threshold="75.0"
get_rawUsed
echo "  timestamp           entries    response time" >> $log
#while (( $(awk 'BEGIN {print ("'$rawUsed'" < "'$threshold'")}') )); do
while (( $(echo "${rawUsed} < ${threshold}" | bc -l) )); do
    syncPolling=`echo "${syncPolling,,}"`       # force lowercase
    if [[ $syncPolling == "true" ]]; then
        cmdStart=$SECONDS
        get_dataLog
        dataLog_duration=$(($SECONDS - $cmdStart))
        #echo -e "\nsite1 datalog entries ---------------------------------------------------- " >> $log
        echo -e `$DATE` "  $dataLog      $dataLog_duration" 2>&1 >> $log
        #echo "datalog response time: $dataLog_duration" >> $log
    fi

    # Sleep for the poll interval
    sleep "${interval}"
done

echo -n "dataLogPoll.sh: " >> $log   # prefix line with label for parsing
updatelog "** 75% fill mark hit: POLL ending" $log

#echo " " | mail -s "dataLogPoll.sh fill mark hit - terminated" user@company.net

# DONE
