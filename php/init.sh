#!/usr/bin/env bash

UBUNTU_VERSION="${1:-16.04}"
PHP_VERSION="${2:-5.6}"
ENVIRONMENT="${3:-prod}"

# Ignore the post install questions
export DEBIAN_FRONTEND=noninteractive

echo '-- Update Apt --'
apt-get update

echo "-- Install tools and helpers --"
apt-get install -y software-properties-common

echo "-- Install PPA's --"
add-apt-repository ppa:ondrej/php

echo "-- Get PPA ondrej Key --"
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C

echo '-- Update & Upgrade Apt --'
apt-get update
apt-get upgrade

if [ "$ENVIRONMENT" = "dev" ]; then
	echo '-- Install Dev Tools --'
	apt-get install -y \
		vim git dos2unix zip wget lynx curl
fi

echo '-- Install sudo & Apache --'
apt-get install -y \
	sudo apache2

echo "-- Install PHP ${PHP_VERSION} --"
apt-get install -y \
	php${PHP_VERSION} php${PHP_VERSION}-cli php${PHP_VERSION}-common libapache2-mod-php${PHP_VERSION} php${PHP_VERSION} php${PHP_VERSION}-mysql php${PHP_VERSION}-fpm php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mysql php${PHP_VERSION}-bz2 php-xml php${PHP_VERSION}-soap php${PHP_VERSION}-zip
a2enmod proxy_fcgi setenvif
a2enconf php${PHP_VERSION}-fpm

if [ "$ENVIRONMENT" = "dev" ]; then
	echo '-- Install PHPMyAdmin --'
	apt-get install -y phpmyadmin
	echo 'Include /etc/phpmyadmin/apache.conf' >> /etc/apache2/apache2.conf
fi

phpenmod mcrypt

# Change Apache settings (User: vagrant, Group: vagrant)
sed -i 's/www-data/vagrant/g' /etc/apache2/envvars

# Change PHP settings (short_open_tag, ...)
sed 's/short_open_tag = Off/short_open_tag = On/g' -i /etc/php/${PHP_VERSION}/apache2/php.ini
sed 's/^post_max_size.*$/post_max_size = 50M/g' -i /etc/php/${PHP_VERSION}/apache2/php.ini
sed 's/^upload_max_filesize.*$/upload_max_filesize = 50M/g' -i /etc/php/${PHP_VERSION}/apache2/php.ini
sed 's/^max_execution_time = .*/max_execution_time = 240/g' -i /etc/php/${PHP_VERSION}/apache2/php.ini
sed 's/^; max_input_vars = .*/max_input_vars = 1500/g' -i /etc/php/${PHP_VERSION}/apache2/php.ini

# Delete default apache web dir and symlink mounted vagrant dir from host machine
# --------------------
rm -rf /var/www/html
ln -fs /vagrant/public /var/www/html

echo '-- Install Composer --'
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/bin/composer
chmod +x /usr/bin/composer

# Replace contents of default Apache vhost
# --------------------
cat > /etc/apache2/sites-enabled/000-default.conf <<EOF
NameVirtualHost *:8080
Listen 8080
<VirtualHost *:80>
  DocumentRoot "/var/www/html"
  ServerName localhost
  <Directory "/var/www/html">
    AllowOverride All
  </Directory>
</VirtualHost>
<VirtualHost *:8080>
  DocumentRoot "/var/www/html"
  ServerName localhost
  <Directory "/var/www/html">
    AllowOverride All
  </Directory>
</VirtualHost>
EOF

if [ "$ENVIRONMENT" = "dev" ]; then
	echo '-- Activate XDebug --'
	cat >> /etc/php/5.6/apache2/php.ini <<EOF
[xdebug]
xdebug.remote_enable=1
xdebug.remote_host="172.17.0.1"
xdebug.remote_port=9000
xdebug.remote_handler="dbgp"
EOF
fi

a2enmod rewrite

# Mysql
# --------------------
# Install MySQL quietly
echo 'Install MySQL...'
apt-get -q -y install mysql-server

# Activate mysql root user from outside
mysql -u root <<EOF
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '';
FLUSH PRIVILEGES;
EOF

# Custom Linux/Bash settings
echo 'alias dir="ls -al"' >> /etc/profile
echo 'alias root="sudo -i"' >> /etc/profile
echo 'cd /vagrant/public' >> /etc/profile

# Install imagemagick
echo 'Install imagemagick...'
apt-get install -y imagemagick libmagickwand-dev

# install mailling softtware
echo 'Install mailling software'
apt-get install -y postfix

if [ "$ENVIRONMENT" = "dev" ]; then
	# install imap + roundcube
	apt-get install -y courier-imap roundcube

	# activate history page up/down in inputrc
	sed 's/^# \(.*history-search.*\)$/\1/g' -i /etc/inputrc

	# activate AllowNoPassword in phpmyadmin config
	sed 's#// \(.*AllowNoPassword.*\)$#\1#g' -i /etc/phpmyadmin/config.inc.php

	# create vagrant maildir
	mkdir /home/vagrant
	chown vagrant:vagrant /home/vagrant
	su vagrant -c 'maildirmake /home/vagrant/Maildir'

	# modify postfix main.cf
	cat >> /etc/postfix/main.cf << EOF
home_mailbox = Maildir/
mailbox_command =
virtual_maps = regexp:/etc/postfix/virtual-regexp
EOF

	# create postfix virtual-regexp
	cat > /etc/postfix/virtual-regexp << EOF
/.+@.+/ vagrant@localhost
EOF
	postmap /etc/postfix/virtual-regexp

	# disable postfix bouncing
	sed 's/^.*bounce.*$/#\0/g' -i /etc/postfix/master.cf

	# activate roundcube aliases
	sed 's/^# *\(.*Alias.*\)$/\1/g' -i /etc/roundcube/apache.conf

	# fix roundcube permissions
	chown vagrant /etc/roundcube/ -R
fi
