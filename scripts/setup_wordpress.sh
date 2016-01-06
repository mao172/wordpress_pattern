#!/bin/sh -e
set -o pipefail

[ -f scripts/functions.sh ] && source scripts/functions.sh

#
# function:: setup_wordpress
#
function setup_wordpress() {
  local dbname=mysql
  local dbsvcname=mysqld
  if [ "$(os_version)" == "7" ]; then
    dbname=mariadb
    dbsvcname=mariadb
  fi

  # Install dependencies
  yum -y update
  yum -y install python-setuptools
  easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz
  yum -y install httpd ${dbname}-server
  yum -y install php php-mysql php-mbstring php-gd
  service_ctl enable httpd
  service_ctl enable ${dbsvcname}


  # Create Database User
  service_ctl start ${dbsvcname}
  if [ ! -f /var/lib/mysql/mysql.sock ]; then
    touch /var/lib/mysql/mysql.sock
    chown mysql:mysql /var/lib/mysql
    service_ctl restart ${dbsvcname}
  fi

  if [ -f ~/.wordpress_mysql_password ]; then
    wordpress_mysql_password=$(cat ~/.wordpress_mysql_password)
  else
    wordpress_mysql_password=$(head -c16 /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
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

role=$1

if [ "${role}" == "wordpress" ]; then
  setup_wordpress
else
  echo "Unsupported role '${role}'."
fi
