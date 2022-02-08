#!/bin/bash
EXPECTED_ARGS=1
if [ $# -eq $EXPECTED_ARGS ] ; then
  comment=$1
else
  echo "Usage: $(basename $0) <test_comment>"
  exit 1
fi
./runit_small-fill.sh $comment
sleep 5m
./runit_small-hybrid.sh new-$comment
radosgw-admin gc process --include-all &
radosgw-admin gc process --include-all &
radosgw-admin gc process --include-all &
sleep 5m
./runit_small-hybrid-48hr.sh $comment
radosgw-admin gc process --include-all &
radosgw-admin gc process --include-all &
radosgw-admin gc process --include-all &
sleep 5m
./runit_small-hybrid.sh aged-$comment
radosgw-admin gc process --include-all &
radosgw-admin gc process --include-all &
radosgw-admin gc process --include-all &
sleep 5m
./runit_small-delWrite.sh $comment
