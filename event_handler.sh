#!/bin/sh -e
set -o pipefail
[ -f lib/functions.sh ] && source lib/functions.sh
[ -f lib/events.sh ] && source lib/events.sh

role=$1
event=$2

if [ "${role}" == "wordpress" ]; then
  if [ "${event}" == "setup" ]; then
    setup_wordpress
  elif [ "${event}" == "configure" ]; then
    configure_wordpress
  elif [ "${event}" == "deploy" ]; then
    # not implemented yet
    true
  elif [ "${event}" == "backup" ]; then
    # do nothing
    true
  elif [ "${event}" == "restore" ]; then
    # do nothing
    true
  elif [ "${event}" == "spec" ]; then
    spec_wordpress
  else
    echo "Unsupported event '${event}'."
  fi
else
  echo "Unsupported role '${role}'."
fi
