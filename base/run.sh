#!/bin/sh

/etc/init.d/postfix restart
/etc/init.d/mysql restart
/etc/init.d/apache2 restart
/etc/init.d/rc.local restart

sleep infinity
