#!/bin/sh -e
set -o pipefail
[ -f lib/functions.sh ] && source lib/functions.sh
[ -f lib/events.sh ] && source lib/events.sh

role=$1
event=$2

if [ "${role}" == "wordpress" ]; then
  if [ "${event}" == "setup" ]; then
    setup_wordpress
  else
    echo "Unsupported event '${event}'."
  fi
else
  echo "Unsupported role '${role}'."
fi
