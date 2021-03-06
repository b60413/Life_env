$web_package = ["apache2", "memcached", "php5", "php5-mysql", "php5-cli", "php5-curl", "php5-dev", "php-pear", "php5-memcache", "php5-sqlite", "libapache2-mod-php5", "phpmyadmin", "git", "ruby", "libcompass-ruby1.8", "ruby-compass"]
$db_package = ["mysql-server"]
$mongodb_package = ["mongodb-10gen"]

node base {
	$web_host_name = "life.localhost"
	
	$db_host_name = "life_db.localhost"
	$db_ip_address = "192.168.100.3"
	$db_root_pw = "life"
	$db_default_user = "life"
	$db_default_pw = "life"
	
	Exec {
		path => "/bin:/usr/bin:/sbin:/usr/sbin"
	}
	
	exec {
		"apt-get update" :
			command => "apt-get update",
			require => File["/etc/apt/sources.list.d/10gen.list"];
		
		"ntpdate" :
			command => "ntpdate time.stdtime.gov.tw";
		
		"mongodb GPG Key":
			command => "apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10";
	}
	
	file {
		#Set Time Zone to Taipei
		"/etc/localtime" :
			source => "/usr/share/zoneinfo/Asia/Taipei",
			owner => "root",
			group => "root",
			mode => 0644,
			notify => Exec["ntpdate"];
		
		#Set mongodb apt download site
		"/etc/apt/sources.list.d/10gen.list" :
			source => "/etc/puppet/files/apt/sources.list.d/10gen.list",
			owner => "root",
			group => "root",
			mode => 0644,
			require => Exec["mongodb GPG Key"];
	}
}

node "Web" inherits base{
	$web_source_path = "/var/www/life"
	
	package {
		$web_package :
			ensure => "installed",
			require => Exec["apt-get update"];
	}
	
	exec {
		#Install PHP Mongodb Driver
		"install-mongo" :
			unless => "test -e /usr/lib/php5/20090626/mongo.so && echo 'yes'",
			command => "pecl install mongo",
			require => Package["php-pear"];
			
		#Enable Apache SSL Module
		"enable-apache-ssl" :
			unless => "test -e /etc/apache2/mods-enabled/ssl.load && echo 'yes'",
			command => "a2enmod ssl",
			require => Package["apache2"],
			notify => Service["apache2"];
			
		#Link Apache SSL Site Config
		"link-ssl-site" :
			unless => "test -e /etc/apache2/sites-enabled/default-ssl && echo 'yes'",
			command => "ln -s /etc/apache2/sites-available/default-ssl /etc/apache2/sites-enabled/default-ssl",
			require => [File["/etc/apache2/sites-available/default-ssl"], Package["apache2"]],
			notify => Service["apache2"];
	}
	
	file {
		#Install PHP Redis Extension
		"/usr/lib/php5/20090626/redis.so" :
			source => "/etc/puppet/files/php/redis/redis.so",
			owner => "root",
			group => "root",
			mode => 0755,
			require => Package["php5"],
			notify => Service["apache2"];
		
		#Install PHP Redis Extension Config
		"/etc/php5/conf.d/redis.ini" :
			source => "/etc/puppet/files/php/redis/redis.ini",
			owner => "root",
			group => "root",
			mode => 0644,
			require => Package["php5"],
			notify => Service["apache2"];
		
		#Install PHP Mongo Extension Config
		"/etc/php5/conf.d/mongo.ini" :
			source => "/etc/puppet/files/php/mongo/mongo.ini",
			owner => "root",
			group => "root",
			mode => 0644,
			require => [Package["php5"], Exec["install-mongo"]],
			notify => Service["apache2"];
		
		#Set Virtual Host
		"/etc/apache2/sites-available/default" :
			content => template("/etc/puppet/files/apache2/sites-available/default.erb"),
			owner => "root",
			group => "root",
			mode => 0600,
			require => Package["apache2"],
			notify => Service["apache2"];
		
		#Set SSL Virtual Host
		"/etc/apache2/sites-available/default-ssl" :
			content => template("/etc/puppet/files/apache2/sites-available/default-ssl.erb"),
			owner => "root",
			group => "root",
			mode => 0600,
			require => Package["apache2"],
			notify => [Exec["link-ssl-site"], Service["apache2"]];
		
		#Set Rewrite Module Load
		"/etc/apache2/mods-enabled/rewrite.load" :
			ensure => "/etc/apache2/mods-available/rewrite.load",
			require => Package["apache2"],
			notify => Service["apache2"];
		
		#Set PhpMyAdmin Web Alias Config
		"/etc/apache2/mods-enabled/phpmyadmin.conf" :
			ensure => "/etc/phpmyadmin/apache.conf",
			require => [Package["apache2"], Package["php5"], Package["php5-mysql"], Package["libapache2-mod-php5"]],
			notify => Service["apache2"];
		
		#Set PhpMyAdmin Language
		"/etc/phpmyadmin/config.inc.php" :
			source => "/etc/puppet/files/phpmyadmin/config.inc.php",
			owner => "root",
			group => "root",
			mode => 0644,
			require => [Package["php5"], Package["php5-mysql"], Package["phpmyadmin"]];
			
		#Set PhpMyAdmin Language
		"/etc/phpmyadmin/config-db.php" :
			content => template("/etc/puppet/files/phpmyadmin/config-db.php.erb"),
			owner => "root",
			group => "www-data",
			mode => 0640,
			require => [Package["php5"], Package["php5-mysql"], Package["phpmyadmin"]];
	}
	
	service {
		"apache2" :
			ensure => "running",
			enable => true,
			require => Package["apache2"];
	}
}

node "Database" inherits base{
	#$mysql_data_dir = "/var/lib/bravomix-mysql"
	
	package {
		$db_package :
			ensure => "installed",
			require => Exec["apt-get update"];
	    "apparmor" :
		    ensure => "purged";
	}
	
	file {
		#Set MySQL Config
		"/etc/mysql/my.cnf" :
			content => template("/etc/puppet/files/mysql/my.cnf.erb"),
			owner => "root",
			group => "root",
			mode => 0644,
			require => Package["mysql-server"],
			notify => Service["mysql"];
	}
	
	exec {
		#Set MySQL Root Password
		"mysql-root-passwd" :
			unless => "mysql -uroot -p$db_root_pw",
			command => "mysqladmin -u root password $db_root_pw",
			require => Package["mysql-server"],
			notify => Service["mysql"];
		
		#Create MySQL Default User
		"mysql-default-user-create" :
			unless => "mysql -u$db_default_user -p$db_default_pw",
			command => "mysql -uroot -p$db_root_pw -e \"GRANT ALL ON *.* TO '$db_default_user'@'%' IDENTIFIED BY '$db_default_pw'\"",
			require => [Package["mysql-server"], Exec["mysql-root-passwd"]],
			notify => Service["mysql"];
	}
	
	service {
		"mysql" :
			ensure => "running",
			enable => true;
	}
}

node "Mongodb1" inherits base{
	package {
		$mongodb_package :
			ensure => "installed",
			require => Exec["apt-get update"];
	}
	
	service {
		"mongodb" :
			ensure => "stopped",
			enable => true,
			require => Package["mongodb-10gen"];
	}
}

node "Mongodb2" inherits base{
	package {
		$mongodb_package :
			ensure => "installed",
			require => Exec["apt-get update"];
	}
	
	service {
		"mongodb" :
			ensure => "stopped",
			enable => true,
			require => Package["mongodb-10gen"];
	}
}