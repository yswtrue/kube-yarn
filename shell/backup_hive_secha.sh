#!/bin/bash

databases=$(hive -e 'show databases;')
for database in $databases;
do
    echo -e "CREATE DATABASE IF NOT EXISTS ${database};use ${database};" > ${database}_secha.sql
    #获取hive表定义
    ret=$(hive -e "use ${database};show tables;"|grep -v _es|grep -v _hb|grep -v importinfo)

    for table in $ret;
    do
        echo -e "drop if exists table $table;" >> ${database}_secha.sql
        hive -e "use ${database};show create table $table" >> ${database}_secha.sql
        echo -e ';' >> ${database}_secha.sql
        echo -e "MSCK REPAIR TABLE $table;"  >> ${database}_secha.sql
        # listpartitions=`hive -e "use $database; show partitions ${table}"`
        #
        # for tablepart in $listpartitions
        # do
        #    partname=`echo ${tablepart/=/=\"}`
        #    echo $partname
        #    echo "ALTER TABLE $table ADD PARTITION ($partname\");" >> ${database}_secha.sql
        # done
    done

done
