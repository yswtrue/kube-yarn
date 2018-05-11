FROM java:8-jre

# Add native libs
ARG HADOOP_VERSION=
ADD hadoop-${HADOOP_VERSION}.tar.gz /usr/local
ADD hadoop-native-${HADOOP_VERSION}.tar /usr/local/hadoop-${HADOOP_VERSION}/lib/native

ARG SPARK_VERSION=2.3.0
ARG SPARK_HADOOP_VERSION=2.7
ADD spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_VERSION}.tgz /usr/local

ENV HADOOP_PREFIX=/usr/local/hadoop \
    HADOOP_COMMON_HOME=/usr/local/hadoop \
    HADOOP_HDFS_HOME=/usr/local/hadoop \
    HADOOP_MAPRED_HOME=/usr/local/hadoop \
    HADOOP_YARN_HOME=/usr/local/hadoop \
    HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop \
    YARN_CONF_DIR=/usr/local/hadoop/etc/hadoop \
    SPARK_PREFIX=/usr/local/spark \
    SPARK_CONF_DIR=/usr/local/spark/conf \
    PATH=${PATH}:/usr/local/hadoop/bin:/usr/local/spark/bin

RUN \
  cd /usr/local && ln -s ./hadoop-${HADOOP_VERSION} hadoop && \
  ln -s ./spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_VERSION} spark
  # rm -f ${HADOOP_PREFIX}/logs/*

WORKDIR $HADOOP_PREFIX

# Hdfs ports
EXPOSE 50010 50020 50070 50075 50090 8020 9000
# Mapred ports
EXPOSE 19888
#Yarn ports
EXPOSE 8030 8031 8032 8033 8040 8042 8088
#Other ports
EXPOSE 49707 2122
