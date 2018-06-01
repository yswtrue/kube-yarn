#!/bin/bash

params=$@
set_mariadb=0
update_host=0
function usage()
{
    echo "help: init_system.sh [--set_mariadb|-d] [--help|-h]
    if there is a file named custom_hosts it will append to /etc/hosts"
}

function init()
{
    echo 'Start to init system'
    echo 'Updating system'
    yum update -y

    echo 'Installing packages'
    yum install -y epel-release

    yum install -y java-1.7.0-openjdk.x86_64 java-1.7.0-openjdk-devel.x86_64 openssl openssh mariadb.x86_64 mariadb-server.x86_64 python2-pip.noarch python-devel ntp.x86_64

    echo 'Stoping firewalld'
    systemctl stop firewalld
    systemctl disable firewalld

    echo 'Adding user'
    groupadd hadoop
    useradd -m -g hadoop hadoop
    echo 'Please set password of user hadoop'
    passwd hadoop

    echo 'Setting up ntp'
    ntpdate stdtime.gov.hk
    systemctl start ntpd
    systemctl enable ntpd
    clock -uw

    if [[ $update_host -eq 1 && -f 'custom_hosts' ]];then
        echo 'Appending hosts'
        cat custom_hosts >> /etc/hosts
    fi

    if [ $set_mariadb -eq 1 ];then
        echo 'Initing mysql database'
        systemctl enable mariadb

        systemctl start mariadb

        echo 'Please setup your mysql'
        mysql_secure_installation

        echo "
CREATE USER 'hive'@'%';
CREATE DATABASE hive;
GRANT ALL PRIVILEGES ON hive.* To 'hive'@'%' IDENTIFIED BY 'hive';
FLUSH PRIVILEGES;" > tmp.sql

        echo 'Please input your mysql password'
        mysql -uroot -p < tmp.sql
        rm tmp.sql
    fi
}


for p in $params;do
    case $p in
        --set_mariadb | -d )
            set_mariadb=1
            ;;
        --update_host | -h )
            update_host=1
            ;;
        --help )
            usage
            exit
            ;;
    esac
done
init
