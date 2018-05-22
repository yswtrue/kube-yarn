#!/bin/bash

files=$(find * -name '*.sh' -not -name 'tmp.sh')
for file in $files;
do
    echo $file;
    /opt/hive/bin/hive -f $file;
done