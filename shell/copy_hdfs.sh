#!/bin/bash

src=$1

dest=$2

for p in `hadoop dfs -ls ${src}/ | awk '{if(NR>1)print}' | rev| cut -d '/' -f -1 | rev`;
do
    if [ p != 'tmp' ]; then
        hdfs dfs -rm -r ${dest}/$p;
        hdfs dfs -cp ${src}/$p ${dest}/$p;
    fi
done;
