# Copyright 2016 Comcast Cable Communications Management, LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

NAMESPACE=yarn-cluster
ENTITIES=namespace
MANIFESTS=./manifests

NAMESPACE_FILES_BASE=yarn-cluster-namespace.yaml
NAMESPACE_FILES=$(addprefix $(MANIFESTS)/,yarn-cluster-namespace.yaml)

HDFS_FILES_BASE=hdfs-nn-statefulset.yaml hdfs-dn-statefulset.yaml
HDFS_FILES=$(addprefix $(MANIFESTS)/,$(HDFS_FILES_BASE))

YARN_FILES_BASE=yarn-rm-statefulset.yaml yarn-nm-statefulset.yaml
YARN_FILES=$(addprefix $(MANIFESTS)/,$(YARN_FILES_BASE))

ZEPPELIN_FILES_BASE=zeppelin-statefulset.yaml
ZEPPELIN_FILES=$(addprefix $(MANIFESTS)/,$(ZEPPELIN_FILES_BASE))

SPARK_FILES_BASE=spark-history-deployment.yaml
SPARK_FILES=$(addprefix $(MANIFESTS)/,$(SPARK_FILES_BASE))

HIVE_FILES_BASE=hive-statefulset.yaml
HIVE_FILES=$(addprefix $(MANIFESTS)/,$(HIVE_FILES_BASE))

FLUME_FILES_BASE=flume-statefulset.yaml
FLUME_FILES=$(addprefix $(MANIFESTS)/,$(FLUME_FILES_BASE))

all: init create-apps
init: create-ns create-configmap
clean: delete-apps delete-configmap delete-ns
	@while [[ -n `kubectl get ns -o json | jq 'select(.items[].status.phase=="Terminating") | true'` ]]; do echo "Waiting for $(NAMESPACE) namespace termination" ; sleep 5; done

### Executable dependencies
KUBECTL_BIN := $(shell command -v kubectl 2> /dev/null)
kubectl:
ifndef KUBECTL_BIN
	$(warning installing kubectl)
	curl -sf https://storage.googleapis.com/kubernetes-release/release/v1.3.3/bin/darwin/amd64/kubectl > /usr/local/bin/kubectl
	chmod +x /usr/local/bin/kubectl
endif
	$(eval KUBECTL := kubectl --namespace $(NAMESPACE))

# Create by file
$(MANIFESTS)/%.yaml: kubectl
	$(KUBECTL) create -f $@

# Delete by file
$(MANIFESTS)/%.yaml.delete: kubectl
	-$(KUBECTL) delete -f $(@:.delete=)

# Delete pod name
delete-pod-%: kubectl
	$(KUBECTL) delete pod $*

delete-statefulset-pods-%: kubectl
	-@for pod in `$(KUBECTL) get pods -l component=$* -o json | jq -r '.items[].metadata.name'`; do make delete-pod-$$pod; done

### Namespace
create-ns: $(NAMESPACE_FILES)
	@while [[ -z `kubectl get ns --selector=name=$(NAMESPACE) -o json | jq 'select(.items[].status.phase=="Active") | true'` ]]; do echo "Waiting for $(NAMESPACE) namespace creation" ; sleep 5; done

delete-ns: $(addsuffix .delete,$(NAMESPACE_FILES))


### Config Map
create-configmap: kubectl
	$(KUBECTL) create configmap hadoop-config --from-file=artifacts

delete-configmap: kubectl
	-$(KUBECTL) delete configmap hadoop-config

get-configmap: kubectl
	$(KUBECTL) get configmap hadoop-config -o=yaml


### All apps
create-apps: create-hdfs create-yarn create-zeppelin create-spark create-hive create-flume
delete-apps: delete-zeppelin delete-yarn delete-hdfs delete-spark delete-hive delete-flume


### HDFS
create-hdfs: $(HDFS_FILES)
delete-hdfs: $(addsuffix .delete,$(HDFS_FILES)) delete-statefulset-pods-hdfs-dn delete-statefulset-pods-hdfs-nn
scale-dn: kubectl
	@CURR=`$(KUBECTL) get statefulset hdfs-dn -o json | jq -r '.status.replicas'` ; \
	IN="" && until [ -n "$$IN" ]; do read -p "Enter number of HDFS Data Node replicas (current: $$CURR): " IN; done ; \
	$(KUBECTL) patch statefulset hdfs-dn -p '{"spec":{"replicas": '$$IN'}}'

### YARN
create-yarn: $(YARN_FILES)
delete-yarn: delete-yarn-rm-pf $(addsuffix .delete,$(YARN_FILES)) delete-statefulset-pods-yarn-nm delete-statefulset-pods-yarn-rm
scale-nm: kubectl
	@CURR=`$(KUBECTL) get statefulset yarn-nm -o json | jq -r '.status.replicas'` ; \
	IN="" && until [ -n "$$IN" ]; do read -p "Enter number of YARN Node Manager replicas (current: $$CURR): " IN; done ; \
	$(KUBECTL) patch statefulset yarn-nm -p '{"spec":{"replicas": '$$IN'}}'

### Zeppelin
create-zeppelin: $(ZEPPELIN_FILES)
delete-zeppelin: delete-zeppelin-pf $(addsuffix .delete,$(ZEPPELIN_FILES)) delete-statefulset-pods-zeppelin

create-spark: $(SPARK_FILES)
delete-spark: $(addsuffix .delete,$(SPARK_FILES)) delete-statefulset-pods-spark

create-hive: $(HIVE_FILES)
delete-hive: $(addsuffix .delete,$(HIVE_FILES)) delete-statefulset-pods-hive

create-flume: $(FLUME_FILES)
delete-flume: $(addsuffix .delete,$(FLUME_FILES)) delete-statefulset-pods-flume

### Helper targets
get-ns: kubectl
	$(KUBECTL) get ns

get-statefulsets: kubectl
	$(KUBECTL) get statefulsets

get-pods: kubectl
	$(KUBECTL) get pods

get-svc: kubectl
	$(KUBECTL) get services

wait-for-pod-%: kubectl
	@while [[ -z `$(KUBECTL) get pods $* -o json | jq 'select(.status.phase=="Running") | true'` ]]; do echo "Waiting for $* pod" ; sleep 2; done

logs-%: kubectl
	$(KUBECTL) logs $*

get-pod-%: wait-for-pod-%
	@echo "$*"

shell-%: wait-for-pod-%
	$(KUBECTL) exec -it $* -- bash

dfsreport: wait-for-pod-hdfs-nn-0
	$(KUBECTL) exec -it hdfs-nn-0 -- /usr/local/hadoop/bin/hdfs dfsadmin -report

get-yarn-nodes: wait-for-pod-yarn-rm-0
	$(KUBECTL) exec -it yarn-rm-0 -- /usr/local/hadoop/bin/yarn node -list

pf-rm: wait-for-pod-yarn-rm-0
	$(KUBECTL) port-forward yarn-rm-0 8088:8088 2>/dev/null &

pf-zeppelin: wait-for-pod-zeppelin-0
	$(KUBECTL) port-forward zeppelin-0 8081:8080 2>/dev/null &

pf: pf-rm pf-zeppelin

delete-%-pf: kubectl
	-pkill -f "kubectl.*port-forward.*$*.*"

delete-pf: kubectl delete-zeppelin-pf delete-yarn-rm-pf

HADOOP_VERSION=$(shell grep "image: " manifests/yarn-rm-statefulset.yaml|cut -d'/' -f2|cut -d ':' -f2)
test: wait-for-pod-yarn-nm-0
	$(KUBECTL) exec -it yarn-nm-0 -- /usr/local/hadoop/bin/hadoop jar /usr/local/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-$(HADOOP_VERSION)-tests.jar TestDFSIO -write -nrFiles 5 -fileSize 128MB -resFile /tmp/TestDFSIOwrite.txt

-include localkube.mk
-include custom.mk
