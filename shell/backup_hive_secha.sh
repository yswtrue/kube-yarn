#!/bin/bash

databases=$(hive -e 'show databases;')
mkdir /tmp/hive_export
for database in $databases;
do
    echo -e "CREATE DATABASE IF NOT EXISTS ${database};use ${database};" >> /tmp/hive_export/${database}_secha.sql
    #获取hive表定义
    ret=$(hive -e "use ${database};show tables;"|grep -v _es|grep -v _hb|grep -v importinfo)

    for table in $ret;
    do
        hive -e "use ${database};show create table $table" >> /tmp/hive_export/${database}_secha.sql
        echo -e ';' >> /tmp/hive_export/${database}_secha.sql
        echo -e "MSCK REPAIR TABLE $table;"  >> /tmp/hive_export/${database}_secha.sql
        # listpartitions=`hive -e "use $database; show partitions ${table}"`
        #
        # for tablepart in $listpartitions
        # do
        #    partname=`echo ${tablepart/=/=\"}`
        #    echo $partname
        #    echo "ALTER TABLE $table ADD PARTITION ($partname\");" >> /tmp/hive_export/${database}_secha.sql
        # done
    done

done
