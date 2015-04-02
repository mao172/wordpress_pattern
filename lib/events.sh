#!/bin/sh

function setup_wordpress() {
  # Install dependencies
  yum -y update
  yum -y install python-setuptools
  easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz
  yum -y install httpd mysql-server
  yum -y install php php-mysql php-mbstring php-gd
  chkconfig httpd on
  chkconfig mysqld on

  # Create Database User
  service mysqld start
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

function wordpress_first_settings() {
  # Configure WordPress Settings
  load_cfn_parameters
  sudo -u apache -- /usr/local/bin/wp core install --path=/var/www/wordpress --url="${WordPressUrl}" \
    --title="'${WordPressTitle}'" --admin_user="${WordPressAdminUser}" \
    --admin_password="${WordPressAdminPassword}" --admin_email="${WordPressAdminEmail}"
  sudo -u apache -- /usr/local/bin/wp core update --path=/var/www/wordpress
  sudo -u apache -- /usr/local/bin/wp core update-db --path=/var/www/wordpress
  sudo -u apache -- /usr/local/bin/wp plugin update --all --path=/var/www/wordpress
}

function get_domain() {
  load_cfn_parameters
  if [ -n "${WordPressUrl}" ]; then
    url="${WordPressUrl}"
    proto=`echo "${WordPressUrl}" | sed -e 's,^\(.*://\).*,\1,g'`
    url=`echo "${WordPressUrl/$proto/}"`
    host=`echo "$url" | cut -d/ -f1`
    echo -n "$host"
  else
    self_address=`curl -s "http://169.254.169.254/latest/meta-data/public-ipv4"`
    echo -n "$self_address"
  fi
}

function update_apache_virtual_host() {
  server_name=`get_domain`
  if [ -n "${server_name}" ]; then
    cat > /etc/httpd/conf.d/wordpress.conf <<-EOF
<VirtualHost *:80>
  DocumentRoot "/var/www/wordpress"
  ServerName "${server_name}"
</VirtualHost>
EOF
    service httpd status
    if [ $? -eq 0 ]; then
      service httpd reload
    else
      service httpd restart
    fi
  fi
}

function configure_wordpress() {
  if [ ! -f /tmp/.wordpress_installed ]; then
    wordpress_first_settings
    touch /tmp/.wordpress_installed
  fi
  update_apache_virtual_host
}

function spec_wordpress() {
  # it should response 200 OK
  status_code=`curl -sLI http://localhost/ -o /dev/null -w '%{http_code}\n'`
  if [ "${status_code}" != "200" ]; then
    echo "localhost:80 returns ${status_code}" 1>&2
    curl http://localhost/
    exit 1
  fi
}
