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
