#!/usr/bin/env bash

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

echo '-- Install sudo & Apache --'
apt-get install -y \
	sudo apache2

# Change Apache settings (User: vagrant, Group: vagrant)
sed -i 's/www-data/vagrant/g' /etc/apache2/envvars

# Delete default apache web dir and symlink mounted vagrant dir from host machine
# --------------------
rm -rf /var/www/html
ln -fs /vagrant/public /var/www/html

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

a2enmod rewrite

# Mysql
# --------------------
# Install MySQL quietly
echo '-- Install MySQL --'
apt-get -q -y install mysql-server

# Activate mysql root user from outside
mysql -u root <<EOF
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '';
FLUSH PRIVILEGES;
EOF

# Custom Linux/Bash settings
echo 'alias dir="ls -al"' >> /etc/profile
echo 'alias ll="ls -al"' >> /etc/profile
echo 'alias root="sudo -i"' >> /etc/profile
echo 'cd /vagrant/public' >> /etc/profile

# Install imagemagick
echo '-- Install imagemagick --'
apt-get install -y imagemagick libmagickwand-dev

# install mailling softtware
echo '-- Install postfix --'
apt-get install -y postfix
