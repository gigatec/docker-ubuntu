#!/bin/sh

/etc/init.d/courier-authdaemon start
/etc/init.d/courier-imap restart
/etc/init.d/postfix restart
/etc/init.d/rsync restart
/etc/init.d/mysql restart
/etc/init.d/apache2 restart
/etc/init.d/ondemand start
/etc/init.d/rc.local start

echo "Loading Docker System: ${DOCKER_SYSTEM}..."

case "$DOCKER_SYSTEM" in

wordpress)
	# Copy config file
	cp /vagrant/public/wp-config.php-vagrant /vagrant/public/wp-config.php

	# Import DB (if not exists)
	wpimport

	echo 'Frontend: http://'$VIRTUAL_HOST'/'
	echo 'PHPMyAdmin: http://'$VIRTUAL_HOST'/phpmyadmin/ (User: root, Pass: )'
	echo 'Webmail: http://'$VIRTUAL_HOST'/squirrelmail/ (User: vagrant, Pass: vagrant)'
	;;

magento)
	# Create local.xml Symlink
	cd /vagrant/public/app/etc/
	cp local.xml.vagrant local.xml

	# Import DB (if not exists)
	mageimport

	# Output Magento links
	# Get Magento settings
	cd /vagrant/public/$1
	if [ $(id -u) = "0" ]; then
		MAGE_PREFIX="$(su vagrant -c "magerun db:info prefix" 2> /dev/null)"
		MAGE_BACKEND="$(echo "Mage::getConfig()->getNode('admin/routers/adminhtml/args/frontName')->asArray()" | su vagrant -c "magerun -q -n dev:console" 2> /dev/null | sed -n 's/^=> "\([^"]*\)"/\1/gp')"
	else
		MAGE_PREFIX="$(magerun db:info prefix 2> /dev/null)"
		MAGE_BACKEND="$(echo "Mage::getConfig()->getNode('admin/routers/adminhtml/args/frontName')->asArray()" | magerun -q -n dev:console 2> /dev/null | sed -n 's/^=> "\([^"]*\)"/\1/gp')"
	fi

	echo 'Magento Frontend: http://'$VIRTUAL_HOST'/'
	echo 'Magento Backend: http://'$VIRTUAL_HOST'/'$MAGE_BACKEND'/'
	echo 'PHPMyAdmin: http://'$VIRTUAL_HOST'/phpmyadmin/ (User: root, Pass: )'
	echo 'Webmail: http://'$VIRTUAL_HOST'/squirrelmail/ (User: vagrant, Pass: vagrant)'
	;;

*)
	# Import DB (if not exists)
	dbimport

	echo 'Frontend: http://'$VIRTUAL_HOST'/'
	echo 'PHPMyAdmin: http://'$VIRTUAL_HOST'/phpmyadmin/ (User: root, Pass: )'
	echo 'Webmail: http://'$VIRTUAL_HOST'/squirrelmail/ (User: vagrant, Pass: vagrant)'
	;;

esac
	
# run custom boot.sh if available
if [ -f "/vagrant/boot.sh" ]; then
	dos2unix /vagrant/boot.sh
	sh /vagrant/boot.sh
fi

sleep infinity
