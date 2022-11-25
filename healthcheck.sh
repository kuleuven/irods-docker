#!/bin/sh
RESULT=$(docker healthcheck run $1)
if [ $? -ne 0 ]; then
  exit $?
fi

if [ -n "$RESULT" ]; then
  echo "$RESULT"
  exit 1
fi

exit 0
