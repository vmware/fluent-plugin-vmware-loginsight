# Fluentd plugin for VMware Aria Operations For Logs
# 
# Copyright 2019 VMware, Inc. All Rights Reserved. 
# 
# This product is licensed to you under the MIT license (the "License").  You may not use this product except in compliance with the MIT License.  
# 
# This product may include a number of subcomponents with separate copyright notices and license terms. Your use of these subcomponents is subject to the terms and conditions of the subcomponent's license, as noted in the LICENSE file. 
# 
# SPDX-License-Identifier: MIT

# Builds a photon-based image that contains fluentd, fluent-plugin-vmware-loginsight some of the tools recommended by fluent
# (libjemalloc, oj, assync-http). This image is based on the minimalistic VMware Photon OS so the result is smaller in size.
#
# Fluentd is configured with the default configuration that gets produced by the `fluentd --setup` command. For an example of
# a configuration that uses the fluent-plugin-vmware-loginsight plugin check fluent.conf under the examples dir:
# https://github.com/vmware/fluent-plugin-vmware-loginsight/blob/master/examples/fluent.conf
FROM photon:4.0-20230227

USER root

RUN buildDeps="\
    binutils linux-api-headers glibc-devel \
    make gcc gmp-devel libffi-devel \
    tar bzip2 sed gawk build-essential" \
    #
    # Distro sync and install build dependencies
    && tdnf distro-sync --refresh -y \
    && tdnf remove -y toybox \
    && tdnf install -y $buildDeps ruby \
    #
    # These are not required but are used if available
    && gem install oj -v 3.3.10 \
    && gem install json -v 2.2.0 \
    && gem install async-http -v 0.46.3 \
    #
    # Install fluentd
    && gem install --norc --no-document fluentd \
    && gem install --norc --no-document fluent-plugin-systemd \
    && gem install --norc --no-document i18n \
    && gem install --norc --no-document fluent-plugin-concat \
    && gem install --norc --no-document fluent-plugin-remote_syslog \
    && gem install --norc --no-document fluent-plugin-docker_metadata_filter \
    && gem install --norc --no-document fluent-plugin-detect-exceptions \
    && gem install --norc --no-document fluent-plugin-multi-format-parser \
    && gem install --norc --no-document fluent-plugin-kubernetes_metadata_filter \
    #
    # Install Log Insight plugin
    && gem install --norc --no-document -v 1.4.0 fluent-plugin-vmware-loginsight \
    #
    # Install jemalloc 5.3.0
    && curl -L --output /tmp/jemalloc-5.3.0.tar.bz2 https://github.com/jemalloc/jemalloc/releases/download/5.3.0/jemalloc-5.3.0.tar.bz2 \
    && tar -C /tmp/ -xjvf /tmp/jemalloc-5.3.0.tar.bz2 \
    && cd /tmp/jemalloc-5.3.0 \
    && ./configure && make \
    && mv lib/libjemalloc.so.2 /usr/lib \
    && cd / \
    && rm -rf /tmp/jemalloc-5.3.0* \
    && tdnf remove -y $buildDeps \
    && tdnf clean all \
    && gem sources --clear-all \
    && gem cleanup

# Create default fluent.conf
RUN fluentd --setup /etc/fluentd

# Make sure fluentd picks jemalloc
ENV LD_PRELOAD="/usr/lib/libjemalloc.so.2"

# Standard fluentd ports
EXPOSE 24224 5140

ENTRYPOINT ["fluentd", "-c", "/etc/fluentd/fluent.conf"]
