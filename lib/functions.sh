#!/bin/sh

function consul_kv_get() {
  # $1: consul key
  usage="Usage: consul_kv_get KEY"
  key=${1:?missing key. $usage}
  consul_url="http://localhost:8500/v1/kv/${key}"
  curl --insecure -s $consul_url | jq .[].Value | sed s/\"//g | base64 -d | jq .;
}

function consul_kv_set() {
  # $1: consul key
  # $2: new value
  usage="Usage: consul_kv_set KEY NEW_VALUE"
  key=${1:?missing key. $usage}
  value=${2:?missing value. $usage}
  consul_url="http://localhost:8500/v1/kv/${key}"
  curl --insecure -s -X PUT "${consul_url}" -d "${value}"
}

function load_cfn_parameters() {
  [ -f /opt/cloudconductor/cfn_parameters ] && source /opt/cloudconductor/cfn_parameters
}

function get_consul_parameters() {
  # no arguments
  consul_kv_get "cloudconductor/parameters"
}

function run() {
  local e E T oldIFS
  [[ ! "$-" =~ e ]] || e=1
  [[ ! "$-" =~ E ]] || E=1
  [[ ! "$-" =~ T ]] || T=1

  set +e
  set +E
  set +T

  output="$("$@" 2>&1)"
  status="$?"
  oldIFS=$IFS
  IFS=$'\n' lines=($output)

  IFS=$oldIFS
  [ -z "$e" ] || set -e
  [ -z "$E" ] || set -E
  [ -z "$T" ] || set -T
}

function os_version() {
  if [ -f /etc/redhat-release ]; then
    rpm -qf --queryformat="%{VERSION}" /etc/redhat-release
  fi
}

function service_ctl() {
  local action=$1
  local svcname=$2

  local os_version=$(os_version)

  case ${os_version} in
    '6' )
      service_ctl_el6 ${action} ${svcname} || return $?
      ;;
    '7')
      service_ctl_el7 ${action} ${svcname} || return $?
      ;;
  esac
}

function service_ctl_el6() {
  local action=$1
  local svcname=$2
  run bash -c "service --status-all | grep ${svcname}"
  if [ $status -eq 0 ]; then
    case ${action} in
      'enable' )
        /sbin/chkconfig --add ${svcname}
        /sbin/chkconfig ${svcname} on || return $?
        ;;
      'disable' )
        /sbin/chkconfig ${svcname} off
        service ${svcname} stop
        ;;
      *)
        service ${svcname} ${action} || return $?
        ;;
    esac
  fi
}

function service_ctl_el7() {
  local action=$1
  local svcname=$2

  run bash -c "systemctl --all | grep \"^ *${svcname}\""
  if [ "$status" -eq 0 ]; then
    case ${action} in
      'disable' )
        systemctl stop ${svcname}
        systemctl disable ${svcname}
        ;;
      *)
        systemctl ${action} ${svcname} || return $?
        ;;
    esac
  else
    case ${action} in
      'enable' )
        systemctl enable ${svcname} #|| return $?
        ;;
    esac
  fi
}
