# Fluentd plugin for VMware Aria Operations For Logs
#
# Copyright 2018 VMware, Inc. All Rights Reserved.
#
# This product is licensed to you under the MIT license (the "License").  You may not use this product except in compliance with the MIT License.
#
# This product may include a number of subcomponents with separate copyright notices and license terms. Your use of these subcomponents is subject to the terms and conditions of the subcomponent's license, as noted in the LICENSE file.
#
# SPDX-License-Identifier: MIT


require 'fluent/plugin/output'
require 'json'
require 'net/http'
require 'zlib'
require 'uri'

module Fluent::Plugin
  class VmwareLoginsightOutput < Output
    Fluent::Plugin.register_output('vmware_loginsight', self)

    ### Connection Params ###
    config_param :scheme, :string, :default => 'http'
    # VMware Aria Operations For Logs Host ex. localhost
    config_param :host, :string,  :default => 'localhost'
    # In case we want to post to  multiple hosts. This is futuristic, Fluentd copy plugin can support this as is
    #config_param :hosts, :string, :default => nil
    # VMware Aria Operations For Logs port ex. 9000. Default 80
    config_param :port, :integer, :default => 80
    # VMware Aria Operations For Logs ingestion api path ex. 'api/v1/events/ingest'
    config_param :path, :string, :default => 'api/v1/events/ingest'
    # agent_id generated by your LI
    config_param :agent_id, :string, :default => '0'
    # Credentials if used
    config_param :username, :string, :default => nil
    config_param :password, :string, :default => nil, :secret => true
    # Authentication nil | 'basic'
    config_param :authentication, :string, :default => nil

    # Set Net::HTTP.verify_mode to `OpenSSL::SSL::VERIFY_NONE`
    config_param :ssl_verify, :bool, :default => true
    config_param :ca_file, :string, :default => nil

    ### API Params ###
    # HTTP method
    # post | put
    config_param :http_method, :string, :default => :post
    config_param :http_compress, :bool, :default => true
    # form | json
    config_param :serializer, :string, :default => :json
    config_param :request_retries, :integer, :default => 3
    config_param :request_timeout, :time, :default => 5
    config_param :http_conn_debug, :bool, :default => false
    # in bytes
    config_param :max_batch_size, :integer, :default => 512000

    # Simple rate limiting: ignore any records within `rate_limit_msec`
    # since the last one.
    config_param :rate_limit_msec, :integer, :default => 0
    # Raise errors that were rescued during HTTP requests?
    config_param :raise_on_error, :bool, :default => false
    # Keys from log event whose values should be added as log message/text
    # to VMware Aria Operations For Logs. Note these key/value pairs  won't be added as metadata/fields
    config_param :log_text_keys, :array, default: ["log", "message", "msg"], value_type: :string
    # Flatten hashes to create one key/val pair w/o losing log data
    config_param :flatten_hashes, :bool, :default => true
    # Seperator to use for joining flattened keys
    config_param :flatten_hashes_separator, :string, :default => "_"

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
    config_param :shorten_keys, :hash, value_type: :string, default:
      {
          'kubernetes_':'k8s_',
          'namespace':'ns',
          'labels_':'',
          '_name':'',
          '_hash':'',
          'container_':''
      }

    config_section :buffer do
      config_set_default :@type, "memory"
      config_set_default :chunk_keys, []
      config_set_default :timekey_use_utc, true
    end

    def configure(conf)
      super

      @ssl_verify_mode = @ssl_verify ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      @auth = case @authentication
              when 'basic'
                :basic
              else
                :none
              end

      @last_request_time = nil
    end

    def format_url()
      url = "#{@scheme}://#{host}:#{port}/#{path}/#{agent_id}"
      url
    end

    def set_header(req)
      if @serializer == 'json'
        set_json_header(req)
      end
      if @http_compress
          set_gzip_header(req)
      end
      req
    end

    def set_json_header(req)
      req['Content-Type'] = 'application/json'
      req
    end

    def set_gzip_header(req)
        req['Content-Encoding'] = 'gzip'
        req
      end

    def shorten_key(key)
      # LI doesn't allow some characters in field 'name'
      # like '/', '-', '\', '.', etc. so replace them with @flatten_hashes_separator
      key = key.gsub(/[\/\.\-\\\@]/,@flatten_hashes_separator).downcase
      # shorten field names using provided shorten_keys parameters
      @shorten_keys.each do | match, replace |
          key = key.gsub(match.to_s,replace)
      end
      key
    end

    def create_loginsight_event(time, record)
      flattened_records = {}
      if @flatten_hashes
        flattened_records = flatten_record(record, [])
      else
        flattened_records = record
      end
      fields = []
      keys = []
      log = ''
      flattened_records.each do |key, value|
        begin
          next if value.nil?
          # LI doesn't support duplicate fields, make unique names by appending underscore
          key = shorten_key(key)
          while keys.include?(key)
            key = key + '_'
          end
          keys.push(key)
          key.force_encoding("utf-8")
          # convert value to json string if its a hash and to string if not already a string
          begin
            value = value.to_json if value.is_a?(Hash)
            value = value.to_s
            value = value.frozen? ? value.dup : value # if value is immutable, use a copy.
            value.force_encoding("utf-8")
          rescue Exception=>e
            $log.warn "force_encoding exception: " "#{e.class}, '#{e.message}', " \
                      "\n Request: #{key} #{record.to_json[1..1024]}"
            value = "Exception during conversion: #{e.message}"
          end
        end
        if @log_text_keys.include?(key)
          if log != "#{value}"
            if log.empty?
              log = "#{value}"
            else
              log += " #{value}"
            end
          end
        else
          # If there is time information available, update time for LI. LI ignores
          # time if it is out of the error/adjusment window of 10 mins. in such
          # cases we would still like to preserve time info, so add it as event.
          # TODO Ignore the below block for now. Handle the case for time being in
          #      different formats than milliseconds
          #if ['time', '_source_realtime_timestamp'].include?(key)
          #  time = value
          #end
          fields << {"name" => key, "content" => value}
        end
      end
      event = {
        "fields" => fields,
        "text" => log.gsub(/^$\n/, ''),
        "timestamp" => time * 1000
      }
      event
    end

    def flatten_record(record, prefix=[])
      ret = {}

      case record
        when Hash
          record.each do |key, value|
            if @log_text_keys.include?(key)
              ret.merge!({key.to_s => value})
            else
              ret.merge! flatten_record(value, prefix + [key.to_s])
            end
          end
        when Array
          record.each do |value|
            ret.merge! flatten_record(value, prefix)
          end
        else
          return {prefix.join(@flatten_hashes_separator) => record}
      end
      ret
    end

    def get_body(req)
       body = ""
       if @http_compress
           gzip_body = Zlib::GzipReader.new(StringIO.new(req.body.to_s))
           body = gzip_body.read
       else
           body = req.body
       end
       return body[1..1024]
     end

    def send_request(req, uri)
      is_rate_limited = (@rate_limit_msec != 0 and not @last_request_time.nil?)
      if is_rate_limited and ((Time.now.to_f - @last_request_time) * 1000.0 < @rate_limit_msec)
        $log.info('Dropped request due to rate limiting')
        return
      end
      if @auth and @auth.to_s.eql? "basic"
        req.basic_auth(@username, @password)
      end
      begin
        retries ||= 2
        response = nil
        @last_request_time = Time.now.to_f

        http_conn = Net::HTTP.new(uri.host, uri.port)
        # For debugging, set this
        http_conn.set_debug_output($stdout) if @http_conn_debug
        http_conn.use_ssl = (uri.scheme == 'https')
        if http_conn.use_ssl?
          http_conn.ca_file = @ca_file
        end
        http_conn.verify_mode = @ssl_verify_mode

        response = http_conn.start do |http|
          http.read_timeout = @request_timeout
          http.request(req)
        end
      rescue => e # rescue all StandardErrors
        # server didn't respond
        # Be careful while turning on below log, if LI instance can't be reached and you're sending
        # log-container logs to LI as well, you may end up in a cycle.
        # TODO handle the cyclic case at plugin level if possible.
        # $log.warn "Net::HTTP.#{req.method.capitalize} raises exception: " \
        #   "#{e.class}, '#{e.message}', \n Request: #{get_body(req)}"
        retry unless (retries -= 1).zero?
        raise e if @raise_on_error
      else
         unless response and response.is_a?(Net::HTTPSuccess)
            res_summary = if response
                             "Response Code: #{response.code}\n"\
                             "Response Message: #{response.message}\n" \
                             "Response Body: #{response.body}"
                          else
                             "Response = nil"
                          end
            # ditto cyclic warning
            # $log.warn "Failed to #{req.method} #{uri}\n(#{res_summary})\n" \
            #   "Request Size: #{req.body.size} Request Body: #{get_body(req)}"
         end #end unless
      end # end begin
    end # end send_request

    def set_body(req, event_req)
        if @http_compress
            gzip_body = Zlib::GzipWriter.new(StringIO.new)
            gzip_body << event_req.to_json
            req.body = gzip_body.close.string
        else
            req.body = event_req.to_json
        end
    end

    def send_events(uri, events)
      req = Net::HTTP.const_get(@http_method.to_s.capitalize).new(uri.path)
      event_req = {
        "events" => events
      }
      set_body(req, event_req)
      set_header(req)
      send_request(req, uri)
    end

    def handle_records(chunk)
      url = format_url()
      uri = URI.parse(url)
      events = []
      count = 0
      chunk.each do |time, record|
        new_event = create_loginsight_event(time, record)
        new_event_size = new_event.to_json.size
        if new_event_size > @max_batch_size
            $log.warn "dropping event larger than max_batch_size: #{new_event.to_json[1..1024]}"
        else
          if (count + new_event_size) > @max_batch_size
            send_events(uri, events)
            events = []
            count = 0
          end
          count += new_event_size
          events << new_event
        end
      end
      if count > 0
        send_events(uri, events)
      end
    end

    # Sync Buffered Output
    def write(chunk)
      handle_records(chunk)
    end
  end
end
