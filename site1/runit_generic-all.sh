#!/bin/bash
EXPECTED_ARGS=1
if [ $# -eq $EXPECTED_ARGS ] ; then
  comment=$1
else
  echo "Usage: $(basename $0) <test_comment>"
  exit 1
fi
./runit_generic-fill.sh $comment
sleep 5m
./runit_generic-hybrid.sh new-$comment
radosgw-admin gc process --include-all &
radosgw-admin gc process --include-all &
radosgw-admin gc process --include-all &
sleep 5m
./runit_generic-hybrid-48hr.sh $comment
radosgw-admin gc process --include-all &
radosgw-admin gc process --include-all &
radosgw-admin gc process --include-all &
sleep 5m
./runit_generic-hybrid.sh aged-$comment
radosgw-admin gc process --include-all &
radosgw-admin gc process --include-all &
radosgw-admin gc process --include-all &
sleep 5m
./runit_generic-delWrite.sh $comment
