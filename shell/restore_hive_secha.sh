#!/bin/bash

files=$(find * -name '*.sql')
for file in $files;
do
    echo $file;
    /opt/hive/bin/hive -f $file;
done
