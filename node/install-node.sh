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
#install procps-ng package(dependency resolution for percona-xtradb-cluster)
wget https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/os/Packages/procps-ng-3.3.15-13.el8.x86_64.rpm
rpm -i --force procps-ng-3.3.15-13.el8.x86_64.rpm
#percona-xtradb-cluster install
yum -y install https://repo.percona.com/yum/percona-release-latest.noarch.rpm
percona-release enable-only pxc-80 release
percona-release enable tools release
#set repo centos8
echo 8 > /etc/yum/vars/releasever
yum -y install percona-xtradb-cluster
#percona xtrabackup install
yum -y install percona-xtrabackup-80
#copy my.cnf
cp conf/my.cnf /etc/my.cnf
cp conf/z-devprom.cnf /etc/my.cnf.d/
#install nfs-client
yum -y install nfs-utils nfs4-acl-tools
mount -t nfs $share:/mnt/nfs_shares /var/www
echo "$share:/mnt/nfs_shares /var/www nfs defaults 0 0">>/etc/fstab
mount -a
#install httpd
yum -y install httpd
yum -y install freetype php php-common php-opcache php-pdo php-mysqli php-gd php-mbstring php-dom php-ldap php-json php-bcmath php-zip php-imap
yum -y install libreoffice-base libreoffice-writer

chkconfig httpd on
cp conf/devprom.ini /etc/php.d/99-devprom.ini
cp conf/000-default.conf /etc/httpd/conf.d/devprom.conf
cp conf/httpd.conf /etc/httpd/conf/httpd.conf
service httpd restart && service php-fpm restart
#install haproxy
yum -y install haproxy
cp conf/haproxy.cfg /etc/haproxy/haproxy.cfg
systemctl enable haproxy
#haproxy logging
cp conf/haproxy.conf /etc/rsyslog.d/hapoxy.conf
service haproxy start && service rsyslog restart
#install git
yum -y install git

setsebool -P httpd_can_connect_ldap on
setsebool -P httpd_can_network_connect on
# following is required to run soffice
setenforce 0

echo "Congratulation! All installation steps are done." 