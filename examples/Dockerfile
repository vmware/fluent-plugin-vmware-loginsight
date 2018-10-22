# Fluentd plugin for VMware Log Insight
# 
# Copyright 2018 VMware, Inc. All Rights Reserved. 
# 
# This product is licensed to you under the MIT license (the "License").  You may not use this product except in compliance with the MIT License.  
# 
# This product may include a number of subcomponents with separate copyright notices and license terms. Your use of these subcomponents is subject to the terms and conditions of the subcomponent's license, as noted in the LICENSE file. 
# 
# SPDX-License-Identifier: MIT


FROM fluent/fluentd:v0.14.15-debian-onbuild
# Above image expects the loginsight plugin vmware_loginsight to be available under ./plugins/vmware_loginsight.rb
# and fluentd config under ./fluent.conf by default

USER root

RUN buildDeps="sudo make gcc g++ libc-dev ruby-dev libffi-dev" \
 && apt-get update \
 && apt-get install -y --no-install-recommends $buildDeps \
 && sudo gem install \
        fluent-plugin-systemd \
        fluent-plugin-kubernetes_metadata_filter \
        fluent-plugin-vmware-loginsight \
 && sudo gem sources --clear-all \
 && SUDO_FORCE_REMOVE=yes \
    apt-get purge -y --auto-remove \
                  -o APT::AutoRemove::RecommendsImportant=false \
                  $buildDeps \
 && rm -rf /var/lib/apt/lists/* \
           /home/fluent/.gem/ruby/2.3.0/cache/*.gem \
           /home/root/.gem/ruby/2.3.0/cache/*.gem
