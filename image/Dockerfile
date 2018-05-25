FROM openjdk:8-jre

# Add native libs
ARG HADOOP_VERSION=
ADD hadoop-${HADOOP_VERSION}.tar.gz /usr/local
ADD hadoop-native-${HADOOP_VERSION}.tar /usr/local/hadoop-${HADOOP_VERSION}/lib/native

ARG SPARK_VERSION=2.3.0
ARG SPARK_HADOOP_VERSION=2.7
ADD spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_VERSION}.tgz /usr/local

ARG PYTHON_VERSION=3.6.5
ADD Python-${PYTHON_VERSION}.tgz /tmp

ARG HIVE_VERSION=3.6.5
ADD apache-hive-${HIVE_VERSION}-bin.tar.gz /usr/local

ARG FLUME_VERSION=3.6.5
ADD apache-flume-${FLUME_VERSION}-bin.tar.gz /usr/local

ENV HADOOP_PREFIX=/usr/local/hadoop \
    HADOOP_HOME=/usr/local/hadoop \
    HADOOP_COMMON_HOME=/usr/local/hadoop \
    HADOOP_HDFS_HOME=/usr/local/hadoop \
    HADOOP_MAPRED_HOME=/usr/local/hadoop \
    HADOOP_YARN_HOME=/usr/local/hadoop \
    HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop \
    YARN_CONF_DIR=/usr/local/hadoop/etc/hadoop \
    SPARK_PREFIX=/usr/local/spark \
    SPARK_HOME=/usr/local/spark \
    SPARK_CONF_DIR=/usr/local/spark/conf \
    HIVE_HOME=/usr/local/hive \
    FLUME_HOME=/usr/local/flume \
    PATH=${PATH}:/usr/local/hadoop/bin:/usr/local/spark/bin:/usr/local/hive/bin:/usr/local/flume/bin

RUN \
  cd /usr/local && ln -s ./hadoop-${HADOOP_VERSION} hadoop && \
  ln -s ./spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_VERSION} spark && \
  ln -s ./apache-flume-${FLUME_VERSION}-bin flume && \
  ln -s ./apache-hive-${HIVE_VERSION}-bin hive
  # rm -f ${HADOOP_PREFIX}/logs/*

# install python
RUN apt-get update && \
    apt-get install -y make build-essential libssl-dev zlib1g-dev && \
    apt-get install -y libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm && \
    apt-get install -y libncurses5-dev  libncursesw5-dev xz-utils tk-dev libtcmalloc-minimal4

RUN export LD_PRELOAD="/usr/lib/libtcmalloc_minimal.so.4" && \
    cd /tmp/Python-${PYTHON_VERSION} && \
    ./configure --enable-optimizations && \
    make -j5 && \
    make install

RUN update-alternatives --install /usr/bin/python python /usr/local/bin/python3 50

RUN apt-get update && \
    apt-get install -y libmysql-java procps

RUN ln -s /usr/share/java/*.jar /usr/local/hive/lib/

RUN rm -rf /tmp/*

WORKDIR $HADOOP_PREFIX

# Hdfs ports
EXPOSE 50010 50020 50070 50075 50090 8020 9000
# Mapred ports
EXPOSE 19888
#Yarn ports
EXPOSE 8030 8031 8032 8033 8040 8042 8088
#Other ports
EXPOSE 49707 2122
