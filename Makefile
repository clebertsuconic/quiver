#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

VERSION := $(shell cat VERSION.txt)

DESTDIR := ""
PREFIX := /usr/local
QUIVER_HOME = ${PREFIX}/lib/quiver

TARGETS := \
	build/bin/quiver \
	build/bin/quiver-arrow \
	build/bin/quiver-bench \
	build/bin/quiver-launch \
	build/bin/quiver-server \
	build/exec/quiver-arrow-activemq-artemis-jms \
	build/exec/quiver-arrow-activemq-jms \
	build/exec/quiver-arrow-qpid-jms \
	build/exec/quiver-arrow-qpid-messaging-cpp \
	build/exec/quiver-arrow-qpid-messaging-python \
	build/exec/quiver-arrow-qpid-proton-python \
	build/exec/quiver-arrow-rhea \
	build/exec/quiver-arrow-vertx-proton \
	build/exec/quiver-server-activemq \
	build/exec/quiver-server-activemq-artemis \
	build/exec/quiver-server-arty \
	build/exec/quiver-server-builtin \
	build/exec/quiver-server-qpid-cpp \
	build/exec/quiver-server-qpid-dispatch \
	build/java/quiver-activemq-artemis-jms.jar \
	build/java/quiver-activemq-jms.jar \
	build/java/quiver-qpid-jms.jar \
	build/java/quiver-vertx-proton.jar

CCFLAGS := -Os -std=c++11 -lstdc++ -lqpid-proton -lqpidmessaging -lqpidtypes

ifdef QPID_PROTON_CPP_ENABLED
	TARGETS += build/exec/quiver-arrow-qpid-proton-cpp
	CCFLAGS += -lqpid-proton-cpp
endif

export PATH := ${PWD}/install/bin:${PATH}
export NODE_PATH := /usr/lib/node_modules:${NODE_PATH}

.PHONY: default
default: devel

.PHONY: help
help:
	@echo "build          Build the code"
	@echo "install        Install the code"
	@echo "clean          Clean up the source tree"
	@echo "devel          Build, install, and run a basic test in this checkout"
	@echo "test           Run the tests"

.PHONY: clean
clean:
	rm -rf build
	rm -rf install
	find java -name target -type d -exec rm -rf {} +

.PHONY: build
build: ${TARGETS}

.PHONY: install
install: build
	scripts/install-files --name \*.py python ${DESTDIR}${QUIVER_HOME}/python
	scripts/install-files javascript ${DESTDIR}${QUIVER_HOME}/javascript
	scripts/install-files build/java ${DESTDIR}${QUIVER_HOME}/java
	scripts/install-files build/exec ${DESTDIR}${QUIVER_HOME}/exec
	scripts/install-files build/bin ${DESTDIR}${PREFIX}/bin

.PHONY: devel
devel: PREFIX := ${PWD}/install
devel: install
	quiver q0 --init-only --verbose --arrow cpp
	quiver --quiet --init-only q0 --arrow python
	quiver-arrow send //localhost:12345/a/b/c --init-only
	quiver-bench --init-only
	quiver-launch q0 --init-only
	quiver-server q0 --init-only

.PHONY: test
test: devel
	scripts/test-quiver
	scripts/test-quiver-bench
	scripts/test-quiver-launch

build/bin/%: bin/%.in
	scripts/configure-file -a quiver_home=${QUIVER_HOME} $< $@

build/exec/%: exec/%.in
	scripts/configure-file -a quiver_home=${QUIVER_HOME} $< $@

build/exec/%: exec/%.cpp
	@mkdir -p build/exec
	g++ $< -o $@ ${CCFLAGS}

build/java/quiver-vertx-proton.jar: java/quiver-vertx-proton/pom.xml $(shell find java/quiver-vertx-proton/src -type f)
	@mkdir -p build/java
	cd java/quiver-vertx-proton && mvn clean package
	cp java/quiver-vertx-proton/target/quiver-vertx-proton-${VERSION}-jar-with-dependencies.jar $@

build/java/%.jar: java/pom.xml java/quiver-jms-driver/pom.xml $(shell find java/quiver-jms-driver/src -type f)
	@mkdir -p build/java
	cd java/quiver-jms-driver && mvn install
	cd java && mvn clean package
	cp java/$*/target/$*-${VERSION}-jar-with-dependencies.jar $@

.PHONY: update-rhea
update-rhea:
	rm -rf javascript/node_modules/rhea
	npm install rhea --prefix javascript

.PHONY: update-%
update-%:
	curl "https://raw.githubusercontent.com/ssorj/$*/master/python/$*.py" -o python/$*.py
