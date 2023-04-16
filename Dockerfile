# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#

ARG IMAGE_NAME=registry.access.redhat.com/ubi9/openjdk-11-runtime
ARG IMAGE_TAG=latest

FROM ${IMAGE_NAME}:${IMAGE_TAG}
ARG MAINTAINER="GitarPlayer"
ARG NIFI_VERSION=1.21.0
LABEL maintainer="${MAINTAINER}"

ENV NIFI_BASE_DIR=/opt/nifi \
       NIFI_HOME=${NIFI_BASE_DIR}/nifi-current \
       NIFI_TOOLKIT_HOME=${NIFI_BASE_DIR}/nifi-toolkit-current \
       NIFI_PID_DIR=${NIFI_HOME}/run \
       NIFI_LOG_DIR=${NIFI_HOME}/logs

COPY --from=index.docker.io/apache/nifi:${NIFI_VERSION} --chown=:0 ${NIFI_BASE_DIR} ${NIFI_BASE_DIR}

VOLUME ${NIFI_LOG_DIR} \
       ${NIFI_HOME}/conf \
       ${NIFI_HOME}/database_repository \
       ${NIFI_HOME}/flowfile_repository \
       ${NIFI_HOME}/content_repository \
       ${NIFI_HOME}/provenance_repository \
       ${NIFI_HOME}/state
USER root
ENV SMDEV_CONTAINER_OFF=1
# Clear nifi-env.sh in favour of configuring all environment variables in the Dockerfile
RUN --mount=type=secret,id=org --mount=type=secret,id=activationkey \
       echo "#!/bin/sh\n" > $NIFI_HOME/bin/nifi-env.sh \
       && microdnf install -y subscription-manager \ 
       && subscription-manager register --org=$(cat /run/secrets/org) --activationkey=$(cat /run/secrets/activationkey) \ 
       && microdnf install -y jq xmlstarlet procps \
       && microdnf upgrade -y --refresh --best --nodocs --noplugins --setopt=install_weak_deps=0 \
       && subscription-manager remove --all \
       && subscription-manager unregister \
       && subscription-manager clean \
       && microdnf remove -y subscription-manager \
       && microdnf clean all \ 
       && chown -R :0 ${NIFI_BASE_DIR} \
       && chmod -R g+rwX ${NIFI_BASE_DIR} 

# Web HTTP(s) & Socket Site-to-Site Ports
EXPOSE 8080 8443 10000 8000

WORKDIR ${NIFI_HOME}
USER 1001
# Apply configuration and start NiFi
#
# We need to use the exec form to avoid running our command in a subshell and omitting signals,
# thus being unable to shut down gracefully:
# https://docs.docker.com/engine/reference/builder/#entrypoint
#
# Also we need to use relative path, because the exec form does not invoke a command shell,
# thus normal shell processing does not happen:
# https://docs.docker.com/engine/reference/builder/#exec-form-entrypoint-example
ENTRYPOINT ["../scripts/start.sh"]