# fluent-plugin-vmware-loginsight

[![Gem Version](https://badge.fury.io/rb/fluent-plugin-vmware-loginsight.svg)](https://badge.fury.io/rb/fluent-plugin-vmware-loginsight)

## Overview
output plugin to do forward logs to VMware Aria Operations for Logs

## Installation

### RubyGems

```
$ gem install fluent-plugin-vmware-loginsight
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-vmware-loginsight"
```

And then execute:

```
$ bundle
```

## Usage

```
# Collect all container logs
<source>
  @type tail
  @id in_tail_container_logs
  path /var/log/containers/*.log
  # One could exclude certain logs like:
  #exclude_path ["/var/log/containers/log-collector*.log"]
  pos_file /var/log/fluentd-docker.pos
  read_from_head true
  # Set this watcher to false if you have many files to tail
  enable_stat_watcher false
  refresh_interval 5
  tag kubernetes.*
  # Open below line if you need have filename as tag field (now without prefix kubernetes.)
  # path_key tag
  <parse>
    @type json
    time_key time
    keep_time_key true
    time_format %Y-%m-%dT%H:%M:%S.%NZ
  </parse>
</source>

# Kubernetes metadata filter that tags additional meta data for each container event
<filter kubernetes.**>
  @type kubernetes_metadata
  @id filter_kube_metadata
  kubernetes_url "#{ENV['FLUENT_FILTER_KUBERNETES_URL'] || 'https://' + ENV.fetch('KUBERNETES_SERVICE_HOST') + ':' + ENV.fetch('KUBERNETES_SERVICE_PORT') + '/api'}"
  verify_ssl "#{ENV['KUBERNETES_VERIFY_SSL'] || true}"
  ca_file "#{ENV['KUBERNETES_CA_FILE']}"
  skip_labels "#{ENV['FLUENT_KUBERNETES_METADATA_SKIP_LABELS'] || 'false'}"
  skip_container_metadata "#{ENV['FLUENT_KUBERNETES_METADATA_SKIP_CONTAINER_METADATA'] || 'false'}"
  skip_master_url "#{ENV['FLUENT_KUBERNETES_METADATA_SKIP_MASTER_URL'] || 'false'}"
  skip_namespace_metadata "#{ENV['FLUENT_KUBERNETES_METADATA_SKIP_NAMESPACE_METADATA'] || 'false'}"
</filter>

# Match everything
<match **>
  @type vmware_loginsight
  @id out_vmw_li_all_container_logs
  scheme https
  ssl_verify true
  # VMware Aria Operations For Logs host: One may use IP address or cname
  #host X.X.X.X
  host MY_LOGINSIGHT_HOST
  port 9543
  agent_id XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
  # Keys from log event whose values should be added as log message/text to
  # VMware Aria Operations For Logs. Note these key/value pairs  won't be added as metadata/fields
  log_text_keys ["log","msg","message"]
  # Use this flag if you want to enable http debug logs
  http_conn_debug false
</match>
```

For more examples look at [examples](./examples/)

### Configuration options

```
scheme, :string, :default => 'http' :: Valid Values: http/https 

# VMware Aria Operations For Logs Host ex. localhost
host, :string,  :default => 'localhost' :: Valid Values: loginsight_url | loginsight_ip

# VMware Aria Operations For Logs port ex. 9000
port, :integer, :default => 80

# VMware Aria Operations For Logs ingestion api path ex. 'api/v1/events/ingest'
path, :string, :default => 'api/v1/events/ingest'

# agent_id generated by your LI
agent_id, :string, :default => '0'

# Credentials if used
username, :string, :default => nil
password, :string, :default => nil,

# Authentication
authentication, :string, :default => nil :: Valid Value: nil | basic

# SSL verification flag
ssl_verify, :bool, :default => true :: Valid Value: true | false
# CA Cert filep
ca_file, :string, :default => nil

# HTTP method
http_method, :string, :default => :post :: Valid Value: post

# Serialization
serializer, :string, :default => :json :: Valid Value: json

# Number of retries
request_retries, :integer, :default => 3
# http connection ttl for each request
request_timeout, :time, :default => 5

# If set, enables debug logs for http connection
http_conn_debug, :bool, :default => false :: Valid Value: true | false

# Number of bytes per post request
max_batch_size, :integer, :default => 4000000

# Simple rate limiting: ignore any records within `rate_limit_msec` since the last one
rate_limit_msec, :integer, :default => 0

# Raise errors that were rescued during HTTP requests?
raise_on_error, :bool, :default => false :: Valid Value: true | false 

# Keys from log event whose values should be added as log message/text to VMware Aria Operations For Logs.
# These key/value pairs won't expanded/flattened and won't be added as metadata/fields.
log_text_keys, :array, :default => ["log", "message", "msg"] :: Valid Value: Array of strings

# Flatten hashes to create one key/val pair w/o losing log data
flatten_hashes, :bool, :default => true :: Valid Value: true | false

# Seperator to use for joining flattened keys
flatten_hashes_separator, :string, :default => "_"

# Rename fields names
config_param :rename_fields, :hash, default: {"source" => "log_source"}, value_type: :string

# Keys from log event to rewrite
# for instance from 'kubernetes_namespace' to 'k8s_namespace'
# tags will be rewritten with substring substitution
# and applied in the order present in the hash
# (Hashes enumerate their values in the order that the
# corresponding keys were inserted
# see https://ruby-doc.org/core-2.2.2/Hash.html)
# example config:
# shorten_keys {
#    "__":"_",
#    "container_":"",
#    "kubernetes_":"k8s_",
#    "labels_":"",
# }
shorten_keys, :hash, value_type: :string, default:
        {
            'kubernetes_':'k8s_',
            'namespace':'ns',
            'labels_':'',
            '_name':'',
            '_hash':'',
            'container_':''
        }

```

## Contributing

The fluent-plugin-vmware-loginsight project team welcomes contributions from the community. Before you start working with fluent-plugin-vmware-loginsight, please read our [Developer Certificate of Origin](https://cla.vmware.com/dco). All contributions to this repository must be signed as described on that page. Your signature certifies that you wrote the patch or have the right to pass it on as an open-source patch. For more detailed information, refer to [CONTRIBUTING.md](CONTRIBUTING.md).

## License
Fluentd plugin for VMware Aria Operations For Logs

Copyright 2018 VMware, Inc. All Rights Reserved. 

This product is licensed to you under the MIT license (the "License").  You may not use this product except in compliance with the MIT License.  

This product may include a number of subcomponents with separate copyright notices and license terms. Your use of these subcomponents is subject to the terms and conditions of the subcomponent's license, as noted in the LICENSE file. 

SPDX-License-Identifier: MIT
