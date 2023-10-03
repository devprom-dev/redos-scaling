#!/bin/bash
# Shell script to install DEVPROM application with dependencies on Centos
#
# -------------------------------------------------------------------------
# Version 1.0 (September 21 2023)
# -------------------------------------------------------------------------
# Copyright (c) 2023 Anatoly Seregin <anseregin@yandex.ru>
# This script is licensed under GNU GPL version 2.0 or above
# -------------------------------------------------------------------------

#start mysql service for generate dir and certs
systemctl start mysql@bootstrap.service
#reset temporary root password mysql
read -s -p "Enter MySQL root password. Remember this password. Password: " mysqlrootpassword
echo ""
cat /var/log/mysqld.log | awk '/password/ {print $NF}' | (read; mysql -u root --connect-expired-password --password="$REPLY" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$mysqlrootpassword'";)
#create user for haproxy
mysql -u root --password=$mysqlrootpassword -e "CREATE USER 'haproxy'@'%' IDENTIFIED WITH mysql_native_password"
mysql -u root --password=$mysqlrootpassword -e "FLUSH PRIVILEGES"
#configure mysql for devprom alm
sleep 1
echo "Configure MySQL for Devprom ALM"
read -s -p "Enter MySQL password for devprom user. Remember this password. Password: " mysqldevprompassword
echo ""
mysql -u root --password=$mysqlrootpassword  -e "CREATE USER devprom@localhost IDENTIFIED BY '$mysqldevprompassword'"
mysql -u root --password=$mysqlrootpassword  -e "GRANT ALL PRIVILEGES ON *.* TO devprom@localhost WITH GRANT OPTION"

echo "Congratulation! All confgiguration steps are done."