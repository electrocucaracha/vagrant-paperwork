#!/bin/bash

sed -i "s/nameserver 10.0.2.3/nameserver 8.8.8.8/g" /etc/resolv.conf
/bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=1024
/sbin/mkswap /var/swap.1
/sbin/swapon /var/swap.1

# Configuration

root_db_password=secure
db_name=paperwork
db_user=paperwork
db_password=paperwork

apt-get update && apt-get dist-upgrade

# Database

debconf-set-selections <<< "mysql-server mysql-server/root_password password $root_db_password"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $root_db_password"
apt-get install -y mysql-server

mysql -p$root_db_password -e " CREATE DATABASE IF NOT EXISTS $db_name DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;"
mysql -p$root_db_password -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost' IDENTIFIED BY '$db_password' WITH GRANT OPTION; FLUSH PRIVILEGES;"

# Front End
apt-get install -y apache2 php5 libapache2-mod-php5 git php5-mysql

# Installation of dependecies
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
curl -sL https://deb.nodesource.com/setup | bash
apt-get install -y nodejs git php5-gd php5-mcrypt
ln -s /etc/php5/mods-available/mcrypt.ini /etc/php5/cli/conf.d/20-mcrypt.ini
npm install npm -g

git clone https://github.com/twostairs/paperwork.git /var/www/paperwork
cd /var/www/paperwork/frontend
sed -i "s/\/var\/www\/html/\/var\/www\/paperwork\/frontend\/public/g" deploy/apache.conf 
sed -i "s/AllowOverride All/AllowOverride All\n\tRequire all granted/g" deploy/apache.conf
cp deploy/apache.conf /etc/apache2/sites-enabled/000-default.conf
a2enmod rewrite
php5enmod mcrypt

composer install

npm install -g gulp
npm install
gulp

sed -i "s/'database'  => 'paperwork',/'database'  => '$db_name',/g" app/config/database.php
sed -i "s/'username'  => 'paperwork',/'username'  => '$db_user',/g" app/config/database.php
sed -i "s/'password'  => 'paperwork',/'password'  => '$db_password',/g" app/config/database.php

php artisan migrate --env=development
ln -s public /var/www/html
chown -R www-data:www-data /var/www/paperwork/frontend
service apache2 restart
