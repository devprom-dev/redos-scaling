#!/bin/bash
# Shell script to install DEVPROM application with dependencies on Centos
#
# -------------------------------------------------------------------------
# Version 1.0 (September 21 2023)
# -------------------------------------------------------------------------
# Copyright (c) 2023 Anatoly Seregin <anseregin@yandex.ru>
# This script is licensed under GNU GPL version 2.0 or above
# -------------------------------------------------------------------------

export $(grep -v '^#' .env | xargs)
#install boost-program-options package(dependency resolution for percona-xtradb-arbitrator)
wget https://repo.almalinux.org/almalinux/8/AppStream/x86_64/os/Packages/boost-program-options-1.66.0-13.el8.x86_64.rpm
rpm -i boost-program-options-1.66.0-13.el8.x86_64.rpm
#install percona-xtradb-arbitrator
yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm
percona-release enable-only pxc-80 release
percona-release enable tools release
#set repo centos8
echo 8 > /etc/yum/vars/releasever
yum -y install percona-xtradb-cluster-garbd
#copy garb
cp conf/garb /etc/sysconfig/garb
touch /var/log/garbd.log
systemctl enable garb
#install httpd
yum -y install httpd
#install haproxy
yum -y install haproxy
cp conf/haproxy.cfg /etc/haproxy/haproxy.cfg
#haproxy logging
cp conf/haproxy.conf /etc/rsyslog.d/hapoxy.conf
systemctl enable haproxy
service haproxy start && service rsyslog restart
#install nfs server
yum -y install nfs-utils
systemctl start nfs-server.service
systemctl enable nfs-server.service
mkdir -p /mnt/nfs_shares
cat << EOF >> /etc/exports
/mnt/nfs_shares $share/24(rw,sync,all_squash,root_squash,anonuid=48,anongid=48)
EOF
exportfs -arv
#install devprom alm application
sleep 1
echo "Installing Devprom ALM Application"
mkdir -p /mnt/nfs_shares/devprom
cp -rRu devprom/. /mnt/nfs_shares/devprom/htdocs
mkdir /mnt/nfs_shares/devprom/backup
mkdir /mnt/nfs_shares/devprom/update
mkdir /mnt/nfs_shares/devprom/files
mkdir /mnt/nfs_shares/devprom/logs
chown -R apache:apache /mnt/nfs_shares/devprom
chmod -R 755 /mnt/nfs_shares/devprom
#adding cron task
sleep 1
echo "Adding background task"
echo '* * * * * apache curl -L -m 600 -k "http://127.0.0.1/tasks/command.php?class=runjobs"' >>  /etc/crontab

sleep 1
echo "Restarting crontab"
service crond restart
#install git
yum -y install git

#install openssl and release self-signed certificate for haproxy
yum -y install openssl
openssl req -x509 -nodes -newkey rsa:2048 -keyout /etc/ssl/certs/haproxy.pem -out /etc/ssl/certs/haproxy.pem -days 365

setsebool -P httpd_can_connect_ldap on
setsebool -P httpd_can_network_connect on
#following is required to run soffice
setenforce 0

echo "Congratulations! All installation steps are done."