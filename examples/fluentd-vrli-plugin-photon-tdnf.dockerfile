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
# Furthermore, all of the needed components are installed from the trusted Photon repository by using the tdnf package manager.
#
# Fluentd is configured with the default configuration that gets produced by the `fluentd --setup` command. For an example of
# a configuration that uses the fluent-plugin-vmware-loginsight plugin check fluent.conf under the examples dir:
# https://github.com/vmware/fluent-plugin-vmware-loginsight/blob/master/examples/fluent.conf

FROM photon:3.0-20190705

USER root

# Distro sync and install components
RUN tdnf distro-sync --refresh -y \
    && tdnf install -y \
    rubygem-fluentd-1.6.3 \
    #
    # optional but used by fluentd
    rubygem-oj-3.3.10 \
    rubygem-async-http-0.48.2 \
    jemalloc-4.5.0 \
    #
    # Install VMware Aria Operations For Logs plugin
    rubygem-fluent-plugin-vmware-loginsight-0.1.5

RUN ln -s /usr/lib/ruby/gems/2.5.0/bin/fluentd /usr/bin/fluentd \
    && fluentd --setup

# Make sure fluentd picks jemalloc
ENV LD_PRELOAD="/usr/lib/libjemalloc.so.2"

# Standard fluentd ports
EXPOSE 24224 5140

ENTRYPOINT ["/usr/bin/fluentd"]
