# Devprom

## Базовая установка инфраструктуры из 3 серверов включает в себя 3 скрипта:

```
install-share.sh - скрипт установки и настройки ПО на share сервер
install-node.sh - скрипт установки и настройки ПО на сервер с приложением
configure-percona.sh - первичная настройка и конфигурирование percona-xtradb-cluster
```

К каждому скрипту прилагается .env файл, в котором необходимо изменить ip адреса

Перед запуском скриптов, необходимо отключить selinux, если он включен:

```
sestatus
setenforce 0
```

и выполнить reboot

Далее, необходимо отредактировать конфигурационные файлы, изменив ip адреса, на ваши внутренние ip серверов.

## Настройка share сервера:

В настройку share сервера входит выпуск самоподписного ssl сертификата для работы haproxy. В дальнейшем, замените файл /etc/ssl/certs/haproxy.pem на свой
Переходим в папку share и выкачиваем архив с официального сайта:

```
wget -O devprom.zip https://myalm.ru/download/devprom-zip
unzip devprom.zip
chmod 775 *
```

В конфигурационном файле арбитра share/conf/garb в строке GALERA_NODES изменить ip адреса web серверов web1 и web2
GALERA_NODES="192.168.0.5:4567, 192.168.0.8:4567"
В конфигурационном файле балансировщика share/conf/haproxy.cfg в блоке backend apache-web изменить hostname и ip адреса на свои

Далее запускаем сам скрипт из каталога:
./isntall-share.sh

## Настройка первого web+db сервера:

Переходим на сервер web01
Редактируем конфигурационный файл percona-xtradb node/conf/my.cnf
В строке wsrep_cluster_adress=gcomm:// меняем ip адреса на свои:
В строке wsrep_node_address= указываем ip адрес текущего сервера, на котором будет выполняться скрипт
в строке wsrep_node_name= указываем hostname текущего сервера
Редактируем конфигурационный файл балансировщика haproxy node/conf/haproxy.cfg
В блоке listen меняем tw01 tw02 на hostname и ip адреса своих web+db серверов

Далее запускаем сам скрипт из каталога:
./install-node.sh

После запускаем скрипт для первичной конфигурации мастер ноды percona-xtradb-cluster
./configure-percona.sh

## Настройка второго web+db сервера:

Переходим на сервер web02
Запускаем скрипт из каталога:
./install-node.sh
На самой ноде в /etc/my.cnf меняем строки:
wsrep_node_address=
wsrep_node_name=
В них соответственно указываете hostname и ip адрес второго сервера.

Далее необходимо запустить и остановить mysql в обычном режиме, чтобы он сгенерировал рабочую директорию /var/lib/mysql

```
service mysql start && service mysql stop
```

## После необходимо перенести ssl сертификаты с первого сервера tw01 на сервера tw02 и share сервер.

На первом сервере tw01 выполняем:

```
cd /var/lib/mysql
```

Далее вы можете воспользоваться любым инструментом для копирования файлов. Данный пример при копировании по ssh с помощью scp.
Копируем на второй сервер:

```
scp ca.pem server-cert.pem server-key.pem root@192.168.0.5:/var/lib/mysql
```

И на share сервер:

```
scp ca.pem server-cert.pem server-key.pem root@192.168.0.6:/etc/ssl/certs
```

Затем переходим на share сервер и выполняем chmod, для того чтобы пользователь nobody из под которого работает арбитр garb, смог читать файл:

```
chmod 644 /etc/ssl/certs/server-key.pem
```

Далее собираем кластер percona-xtradb:

На первом узле tw01 проверяем, что mysql запущен в режиме bootstrap
Переходим на второй сервер tw02 и выполняем:

```
service mysql start
```

Переходим на share сервер и выполняем:

```
service garb start
```

Затем возвращаемся на первый сервер tw01 и перезапускаем mysql из режима bootstrap в обычный:

```
systemctl stop mysql@bootstrap.service
service mysql start
```

Заходим в mysql и проверяем статус кластера:

```
mysql -u root -p
show status like 'wsrep%';
```

Значение полей
wsrep_local_state_comment - Synced
wsrep_cluster_size - 3
сообщают о корректно настроенном кластере percona из двух нод + арбитр

## Инструкция по добавлению дополнительных web нод

Для добавления нового сервера необходимо:

Запустить скрипт ./install-node.sh на новом сервере который вы хотите добавить
Остановить на всех серверах percona-xtradb-cluster

```
service mysql stop
```

Отредактировать на всех серверах /etc/my.cnf
В строку wsrep_cluster_address=gcomm:// добавить ip адрес нового сервера

На добавляемом сервере:
В строке wsrep_node_address= изменить ip адрес на адрес сервера
На добавляемом сервере в /etc/haproxy/haproxy.cfg в блоке listen percona-xtradb-cluster
добавить строку с именем сервера и ip адресом, аналогично остальным

На share сервере:
В файле /etc/haproxy/haproxy.cfg в блоке backend apache-web
добавить строку с именем добавляемого сервера и ip адресом, аналогично остальным
В конфигурационном файле арбитра /etc/sysconfig/garb в строку GALERA_NODES= добавить ip адрес добавляемого сервера.
Скопировать ssl сертификаты ca.pem server-cert.pem server-key.pem на новый сервер в /var/lib/mysql

После этого можно запускать percona-xtradb-cluster
Запустить первый узел в режиме bootstrap:

```
systemctl start mysql@bootstrap.service
```

На остальных нодах:

```
service mysql start
```

Запустить garb на share сервере:

```
service garb start
```

Затем перезапустить узел который был запущен в bootstrap режиме:

```
systemctl stop mysql@bootstrap.service
service mysql start
```

Заходим в mysql и проверяем статус кластера: 

```
mysql -u root -p show status like 'wsrep%';
```

Значение полей wsrep_local_state_comment - Synced wsrep_cluster_size - 4 говорит о том, что вы успешно добавили новую ноду.

## Инструкция по настройке инкрементного резервного копирования средствами percona xtrabackup

Создайте каталог для будущих бэкапов

```
mkdir backups
```

Снимите базовый бэкап, который будет служить основой для инкрементных копий:

```
xtrabackup --user=root --password=root_password --backup --target-dir=/backups/pxc_base
```

Далее, добавьте cron задачу, которая будет снимать инкрементные бэкапы, например каждый час:

```
echo '0 * * * * root xtrabackup --user=root --password=root_password --backup --target-dir=/backups/inc_$(date \+\%d\%m\%Y\_\%H) --incremental-basedir=/backups/pxc_base' >> /etc/crontab
```

Перезапустите crond:

```
service crond restart
```

Вы можете использовать и другие схемы по необходимости, например раз в сутки снимать базовую копию, и на её основе раз в час инкрементные:

```
echo '0 0 * * * root xtrabackup --user=root --password=root_password --backup --target-dir=/backups/pxc_base_$(date \+\%d\%m\%Y)' >> /etc/crontab
echo '30 * * * * root xtrabackup --user=root --password=root_password --backup --target-dir=/backups/inc_$(date \+\%d\%m\%Y\_\%H) --incremental-basedir=/backups/pxc_base_$(date \+\%d\%m\%Y)' >> /etc/crontab
```

Важно, чтобы базовая копия успевала сниматься до запуска инкрементных. Вы так же можете настроить отдельного пользователя для бэкапирования и изменить процесс аутентификации

### Подготовка к восстановлению

Чтобы подготовить базовую резервную копию, нужно запустить prepare с флагом --aply-log-only:

```
xtrabackup --prepare --apply-log-only --target-dir=/backups/pxc_base
```

Чтобы применить инкрементную резервную копию за 28.09.2023 на момент времени 17:00 к полной резервной копии, выполните следующую команду:

```
xtrabackup --prepare --apply-log-only --target-dir=/backups/pxc_base --incremental-dir=/backups/inc_2809023_17
```

После подготовки инкрементальные резервные копии аналогичны полным резервным копиям , и их можно восстановить таким же образом.
