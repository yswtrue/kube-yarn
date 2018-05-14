#!/usr/bin/env bash

export SPARK_HISTORY_OPTS="-Dspark.history.ui.port=7777 -Dspark.history.retainedApplications=3 -Dspark.history.fs.logDirectory=hdfs://hdfs-nn:9000/logs/spark"
