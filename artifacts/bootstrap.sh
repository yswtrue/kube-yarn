#!/bin/bash

: ${HADOOP_PREFIX:=/usr/local/hadoop}

. $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh

# Directory to find config artifacts
CONFIG_DIR="/tmp/hadoop-config"

# Copy config files from volume mount
if [ -d ${CONFIG_DIR} ]; then
    cp ${CONFIG_DIR}/* $HADOOP_PREFIX/etc/hadoop/
    cp ${CONFIG_DIR}/* $SPARK_PREFIX/conf/
    cp ${CONFIG_DIR}/* $FLUME_HOME/conf/
else
    echo "ERROR: Could not find config file in $CONFIG_DIR"
    exit 1
fi

# installing libraries if any - (resource urls added comma separated to the ACP system variable)
cd $HADOOP_PREFIX/share/hadoop/common ; for cp in ${ACP//,/ }; do  echo == $cp; curl -LO $cp ; done; cd -

if [[ "${HOSTNAME}" =~ "hdfs-nn" ]]; then
    if [ ! -d "/root/hdfs/namenode" ]; then
        mkdir -p /root/hdfs/namenode
        $HADOOP_PREFIX/bin/hdfs namenode -format -force -nonInteractive
    fi
    sed -i s/hdfs-nn/0.0.0.0/ /usr/local/hadoop/etc/hadoop/core-site.xml
    $HADOOP_PREFIX/sbin/hadoop-daemon.sh start namenode
fi

if [[ "${HOSTNAME}" =~ "hdfs-dn" ]]; then
    mkdir -p /root/hdfs/datanode
    #  wait up to 30 seconds for namenode
    count=0 && while [[ $count -lt 15 && -z `curl -sf http://hdfs-nn:50070` ]]; do echo "Waiting for hdfs-nn" ; ((count=count+1)) ; sleep 2; done
    [[ $count -eq 15 ]] && echo "Timeout waiting for hdfs-nn, exiting." && exit 1
    $HADOOP_PREFIX/sbin/hadoop-daemon.sh start datanode
fi

if [[ "${HOSTNAME}" =~ "yarn-rm" ]]; then
    sed -i s/yarn-rm/0.0.0.0/ $HADOOP_PREFIX/etc/hadoop/yarn-site.xml
    cp ${CONFIG_DIR}/start-yarn-rm.sh $HADOOP_PREFIX/sbin/
    cd $HADOOP_PREFIX/sbin
    chmod +x start-yarn-rm.sh
    ./start-yarn-rm.sh
fi

if [[ "${HOSTNAME}" =~ "yarn-nm" ]]; then
    sed -i '/<\/configuration>/d' $HADOOP_PREFIX/etc/hadoop/yarn-site.xml
    cat >> $HADOOP_PREFIX/etc/hadoop/yarn-site.xml <<- EOM
  <property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>${MY_MEM_LIMIT:-2048}</value>
  </property>

  <property>
    <name>yarn.nodemanager.resource.cpu-vcores</name>
    <value>${MY_CPU_LIMIT:-2}</value>
  </property>
EOM
    echo '</configuration>' >> $HADOOP_PREFIX/etc/hadoop/yarn-site.xml
    cp ${CONFIG_DIR}/start-yarn-nm.sh $HADOOP_PREFIX/sbin/
    cd $HADOOP_PREFIX/sbin
    chmod +x start-yarn-nm.sh

    #  wait up to 30 seconds for resourcemanager
    count=0 && while [[ $count -lt 15 && -z `curl -sf http://yarn-rm:8088/ws/v1/cluster/info` ]]; do echo "Waiting for yarn-rm" ; ((count=count+1)) ; sleep 2; done
    [[ $count -eq 15 ]] && echo "Timeout waiting for hdfs-nn, exiting." && exit 1

    ./start-yarn-nm.sh
fi

if [[ "${HOSTNAME}" =~ "spark-history" ]]; then
    #  wait up to 30 seconds for namenode
    count=0 && while [[ $count -lt 15 && -z `curl -sf http://hdfs-nn:50070` ]]; do echo "Waiting for hdfs-nn" ; ((count=count+1)) ; sleep 2; done
    [[ $count -eq 15 ]] && echo "Timeout waiting for hdfs-nn, exiting." && exit 1
    hdfs dfs -mkdir -p /logs/spark
    # replace spark local ip
    sed -i "s/spark.driver.bindAddress.*/spark.driver.bindAddress\t\t${MY_POD_IP}/g" ${SPARK_HOME}/conf/spark-defaults.conf
    sed -i "s/spark.driver.host.*/spark.driver.host\t\t${MY_POD_IP}/g" ${SPARK_HOME}/conf/spark-defaults.conf
    cd $SPARK_PREFIX/sbin
    chmod +x start-history-server.sh
    ./start-history-server.sh
fi

if [[ "${HOSTNAME}" =~ "hive" ]]; then
    #  wait up to 30 seconds for namenode
    hdfs_count=0 && while [[ $hdfs_count -lt 15 && -z `curl -sf http://hdfs-nn:50070` ]]; do echo "Waiting for hdfs-nn" ; ((hdfs_count=hdfs_count+1)) ; sleep 2; done
    mysql_count=0 && while [[ $mysql_count -lt 15 && -z `curl -sf http://mysql:3306` ]]; do echo "Waiting for mysql" ; ((mysql_count=mysql_count+1)) ; sleep 2; done
    [[ $hdfs_count -eq 15 ]] && echo "Timeout waiting for hdfs-nn, exiting." && exit 1
    [[ $mysql_count -eq 15 ]] && echo "Timeout waiting for mysql, exiting." && exit 1
    hdfs dfs -mkdir -p /tmp
    hdfs dfs -mkdir -p /user/hive/warehouse
    hdfs dfs -chmod g+w /tmp
    hdfs dfs -chmod g+w /user/hive/warehouse
    cd $HIVE_HOME/bin
    schematool  -initSchema -dbType mysql -verbose
    hiveserver2
fi

if [[ "${HOSTNAME}" =~ "flume" ]]; then
    cd $FLUME_HOME
    ./bin/flume-ng agent -c conf -f conf/flume-conf-serializer-mongosink.properties -n agent1 -Dflume.root.logger=DEBUG,LOGFILE -Dflume.monitoring.type=http -Dflume.monitoring.port=34343
fi

if [[ $1 == "-d" ]]; then
    until find ${HADOOP_PREFIX}/logs -mmin -1 | egrep -q '.*'; echo "`date`: Waiting for logs..." ; do sleep 2 ; done
    tail -F ${HADOOP_PREFIX}/logs/* &
    while true; do sleep 1000; done
fi

if [[ $1 == "-bash" ]]; then
    /bin/bash
fi
