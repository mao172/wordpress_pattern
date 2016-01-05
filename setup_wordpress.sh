#!/bin/sh -e
#set -o pipefail
set -o errexit

set -x

LANG=en_US.utf8

run() {
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

os_version() {
  if [ -f /etc/redhat-release ]; then
    rpm -qf --queryformat="%{VERSION}" /etc/redhat-release
  fi
}

#
# function:: service_ctl
#
service_ctl() {
  local action=$1
  local svcname=$2

  local os_version=$(os_version)
#  if [ -f /etc/redhat-release ]; then
#    os_version=$(rpm -qf --queryformat="%{VERSION}" /etc/redhat-release)
#  fi

  case ${os_version} in
    '6' )
      service_ctl_el6 ${action} ${svcname} || return $?
      ;;
    '7')
      service_ctl_el7 ${action} ${svcname} || return $?
      ;;
  esac
}

service_ctl_el6() {
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

service_ctl_el7() {
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

#
# function:: setup_wordpress
#
function setup_wordpress() {
  local db_name=mysql
  local db_svcnm=mysqld
  if [ "$(os_version)" == "7" ]; then
    db_name=mariadb
    db_svcnm=mariadb
  fi

  # Install dependencies
  yum -y update
  yum -y install python-setuptools
  easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz
  yum -y install httpd ${db_name}-server
  yum -y install php php-mysql php-mbstring php-gd
  service_ctl enable httpd
  #service_ctl enable mysqld
  service_ctl enable ${db_svcnm}


  # Create Database User
  #service_ctl start mysqld
  service_ctl start ${db_svcnm}
  if [ ! -f /var/lib/mysql/mysql.sock ]; then
    touch /var/lib/mysql/mysql.sock
    chown mysql:mysql /var/lib/mysql
    service_ctl restart ${db_svcnm}
  fi

  if [ -f ~/.wordpress_mysql_password ]; then
    wordpress_mysql_password=`cat ~/.wordpress_mysql_password`
  else
    wordpress_mysql_password=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1`
    echo $wordpress_mysql_password > ~/.wordpress_mysql_password
  fi
  mysql -u root -e "CREATE DATABASE wordpress CHARACTER SET utf8;"
  mysql -u root -e "GRANT ALL PRIVILEGES ON wordpress.* TO wordpress@localhost IDENTIFIED BY '${wordpress_mysql_password}';"
  mysql -u root -e "FLUSH PRIVILEGES;"

  # Download WordPress
  curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod a+x /usr/local/bin/wp
  [ -d /var/www/wordpress ] || mkdir /var/www/wordpress
  chown apache:apache /var/www/wordpress
  sudo -u apache -- /usr/local/bin/wp core download --path=/var/www/wordpress --locale=ja
  sudo -u apache -- /usr/local/bin/wp core config --path=/var/www/wordpress \
    --dbname=wordpress --dbuser=wordpress --dbpass="${wordpress_mysql_password}"
}

[ -f lib/events.sh ] && source lib/events.sh

role=$1
event=$2

#if [ "${role}" == "wordpress" ]; then
#  if [ "${event}" == "setup" ]; then
    setup_wordpress
#  else
#    echo "Unsupported event '${event}'."
#  fi
#else
#  echo "Unsupported role '${role}'."
#fi
