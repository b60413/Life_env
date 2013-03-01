#!/bin/sh

cd /var/www/BravoMix-Source

if [ ! "$(ls -A ./system/language/zh-TW)" ]; then
	git submodule init
	git submodule update
fi

sed -i "s/\$db\['default'\]\['hostname'\] = 'localhost';/\$db\['default'\]\['hostname'\] = 'db.localhost';/g" application/config/database.php
sed -i "s/\$db\['default'\]\['username'\] = '';/\$db\['default'\]\['username'\] = 'bravomix';/g" application/config/database.php
sed -i "s/\$db\['default'\]\['password'\] = '';/\$db\['default'\]\['password'\] = 'bravomix';/g" application/config/database.php
sed -i "s/\$db\['default'\]\['database'\] = '';/\$db\['default'\]\['database'\] = 'bravomix';/g" application/config/database.php
