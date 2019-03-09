# Copyright (c) 2016-present Sonatype, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM centos:centos7

MAINTAINER Sonatype <cloud-ops@sonatype.com>

LABEL vendor=Sonatype \
      com.sonatype.license="Apache License, Version 2.0" \
      com.sonatype.name="Nexus Repository Manager base image"

ARG NEXUS_VERSION=3.15.2-01
ARG NEXUS_DOWNLOAD_URL=https://download.sonatype.com/nexus/3/nexus-${NEXUS_VERSION}-unix.tar.gz
ARG NEXUS_DOWNLOAD_SHA256_HASH=acde357f5bbc6100eb0d5a4c60a1673d5f1f785e71a36cfa308b8dfa45cf25d0

# configure nexus runtime
ENV SONATYPE_DIR=/opt/sonatype
ENV NEXUS_HOME=${SONATYPE_DIR}/nexus \
    NEXUS_DATA=/nexus-data \
    NEXUS_CONTEXT='' \
    SONATYPE_WORK=${SONATYPE_DIR}/sonatype-work \
    DOCKER_TYPE='docker'

ARG NEXUS_REPOSITORY_MANAGER_COOKBOOK_VERSION="release-0.5.20190212-155606.d1afdfe"
ARG NEXUS_REPOSITORY_MANAGER_COOKBOOK_URL="https://github.com/sonatype/chef-nexus-repository-manager/releases/download/${NEXUS_REPOSITORY_MANAGER_COOKBOOK_VERSION}/chef-nexus-repository-manager.tar.gz"
ARG RUBY_FULL_VERSION=2.5.3
ARG RUBY_MAJOR_VERSION=2.5

ADD solo.json.erb /var/chef/solo.json.erb

# preparing for building ruby from source
RUN yum install -y ntp gcc make zlib-devel openssl-devel hostname

# building ruby from source
RUN mkdir /tmp/ruby \
    && cd /tmp/ruby \
    && curl -L --progress http://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR_VERSION}/ruby-${RUBY_FULL_VERSION}.tar.gz | tar xz \
    && cd ruby-${RUBY_FULL_VERSION} \
    && ./configure --prefix=/opt/ruby --disable-install-doc --disable-install-rdoc --disable-install-capi --without-X11 \
    && make -j4 \
    && make install \
    && cd .. \
    && rm -rf /tmp/ruby

# installing chef
RUN /opt/ruby/bin/gem install chef --no-ri --no-rdoc --no-document

# installing nexus by chef script
RUN /opt/ruby/bin/erb /var/chef/solo.json.erb > /var/chef/solo.json \
    && /opt/ruby/bin/chef-solo \
       --recipe-url ${NEXUS_REPOSITORY_MANAGER_COOKBOOK_URL} \
       --json-attributes /var/chef/solo.json \
    && rpm --rebuilddb \
    && rm -rf /etc/chef \
    && rm -rf /opt/chefdk \
    && rm -rf /var/cache/yum \
    && rm -rf /var/chef

VOLUME ${NEXUS_DATA}

EXPOSE 8081
USER nexus

ENV INSTALL4J_ADD_VM_PARAMS="-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g -Djava.util.prefs.userRoot=${NEXUS_DATA}/javaprefs"

CMD ["sh", "-c", "${SONATYPE_DIR}/start-nexus-repository-manager.sh"]
