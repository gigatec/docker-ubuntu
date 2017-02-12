#!/usr/bin/env bash

UBUNTU_VERSION="${1:-16.04}"
PHP_VERSION="${2:-5.6}"
ENVIRONMENT="${3:-prod}"

# Ignore the post install questions
export DEBIAN_FRONTEND=noninteractive

if [ "$ENVIRONMENT" = "dev" ]; then
	echo '-- Install Dev Tools --'
	apt-get install -y \
		vim git dos2unix zip wget lynx curl
fi

echo "-- Install PHP ${PHP_VERSION} --"
apt-get install -y \
	libapache2-mod-php${PHP_VERSION} \
	php${PHP_VERSION} \
	php${PHP_VERSION}-cli \
	php${PHP_VERSION}-common \
	php${PHP_VERSION}-mysql \
	php${PHP_VERSION}-fpm \
	php${PHP_VERSION}-curl \
	php${PHP_VERSION}-gd \
	php${PHP_VERSION}-mysql \
	php${PHP_VERSION}-bz2 \
	php${PHP_VERSION}-xml \
	php${PHP_VERSION}-soap \
	php${PHP_VERSION}-zip \
	php${PHP_VERSION}-mbstring \
	php${PHP_VERSION}-mcrypt \
	php${PHP_VERSION}-intl

a2enmod proxy_fcgi setenvif
a2enconf php${PHP_VERSION}-fpm

if [ "$ENVIRONMENT" = "dev" ]; then
	echo '-- Install PHPMyAdmin --'
	apt-get install -y phpmyadmin
	echo 'Include /etc/phpmyadmin/apache.conf' >> /etc/apache2/apache2.conf
fi

phpenmod mcrypt
phpenmod mbstring

# Change PHP settings (short_open_tag, ...)
sed 's/short_open_tag = Off/short_open_tag = On/g' -i /etc/php/${PHP_VERSION}/apache2/php.ini
sed 's/^post_max_size.*$/post_max_size = 50M/g' -i /etc/php/${PHP_VERSION}/apache2/php.ini
sed 's/^upload_max_filesize.*$/upload_max_filesize = 50M/g' -i /etc/php/${PHP_VERSION}/apache2/php.ini
sed 's/^max_execution_time = .*/max_execution_time = 240/g' -i /etc/php/${PHP_VERSION}/apache2/php.ini
sed 's/^; max_input_vars = .*/max_input_vars = 1500/g' -i /etc/php/${PHP_VERSION}/apache2/php.ini

echo '-- Install Composer --'
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/bin/composer
chmod +x /usr/bin/composer

if [ "$ENVIRONMENT" = "dev" ]; then
	echo '-- Activate XDebug --'
	apt-get install -y php-xdebug
	cat >> /etc/php/${PHP_VERSION}/apache2/php.ini <<EOF
[xdebug]
xdebug.remote_enable=1
xdebug.remote_host="172.17.0.1"
xdebug.remote_port=9000
xdebug.remote_handler="dbgp"
EOF
fi

if [ "$ENVIRONMENT" = "dev" ]; then
	# install imap 
	apt-get install -y courier-imap 

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

	# install squirrelmail and set vagrant passwd
	apt-get install -y squirrelmail
	chown -R vagrant /etc/squirrelmail/ /var/lib/squirrelmail/
	ln -s /etc/squirrelmail/apache.conf /etc/apache2/conf-enabled/squirrelmail.conf
	usermod -p '$6$VIHcMG0a$ACsnlC6J0LzqraKV5a9sm3jgBypFp4kCd7ju9BYgcdMeQtqVo1wuNHhF3MEWQUQVsKrzKgcHQZUc6p8PCZYFK.' vagrant
fi
