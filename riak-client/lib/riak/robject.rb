# Copyright 2010 Sean Cribbs, Sonian Inc., and Basho Technologies, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
require 'riak'
require 'set'

module Riak
  # Parent class of all object types supported by ripple. {Riak::RObject} represents
  # the data and metadata stored in a bucket/key pair in the Riak database.
  class RObject
    include Util
    include Util::Translation
    include Util::Escape

    # @return [Bucket] the bucket in which this object is contained
    attr_accessor :bucket

    # @return [String] the key of this object within its bucket
    attr_accessor :key

    # @return [String] the MIME content type of the object
    attr_accessor :content_type

    # @return [String] the Riak vector clock for the object
    attr_accessor :vclock
    alias_attribute :vector_clock, :vclock

    # @return [Object] the data stored in Riak at this object's key. Varies in format by content-type, defaulting to String from the response body.
    attr_accessor :data

    # @return [Set<Link>] a Set of {Riak::Link} objects for relationships between this object and other resources
    attr_accessor :links

    # @return [String] the ETag header from the most recent HTTP response, useful for caching and reloading
    attr_accessor :etag

    # @return [Time] the Last-Modified header from the most recent HTTP response, useful for caching and reloading
    attr_accessor :last_modified

    # @return [Hash] a hash of any X-Riak-Meta-* headers that were in the HTTP response, keyed on the trailing portion
    attr_accessor :meta

    # @return [Boolean] a flag indicating whether this object has conflicting sibling objects
    attr_accessor :conflict

    # @param [Array] siblings a list of RObjects that are a sibling to this one
    attr_writer :siblings

    # Create a new object from the response we get from map/reduce.
    # @param [Client] client an active client object to contact the server with
    # @param [Array] map_response the response given us from a map operation
    # @return [RObject] the created RObject
    #
    # :nodoc:
    #
    # An example of a response:
    #
    # [{"bucket"=>"users",
    #   "key"=>"A2cbUQ2KEMbeyWGtdz97LoTi1DN",
    #   "vclock"=>
    #    "a85hYGBgzmDKBVIsCfs+fc9gSmTMY2WQYN9wlA8q/HvGVn+osCKScFV3/hKosDpIOAsA",
    #   "values"=>
    #    [...]}]
    def self.generate_from_map_reduce(client,response)
      robj = new(client.bucket(response[0]['bucket']), response[0]['key'])
      robj.vclock = response[0]['vclock'] if response[0]['vclock'].present?

      if response[0]['values'].length == 1
        robj.load_from_map_reduce(response[0]['values'][0])
      else
        robj.conflict = true
        robj.siblings = response[0]['values'].map do |values|
          sibling = new(client.bucket(response[0]['bucket']), response[0]['key'])
          sibling.vclock = robj.vclock
          sibling.load_from_map_reduce(values)
        end
      end

      robj
    end

    # Create a new object manually
    # @param [Bucket] bucket the bucket in which the object exists
    # @param [String] key the key at which the object resides. If nil, a key will be assigned when the object is saved.
    # @see Bucket#get
    def initialize(bucket, key=nil)
      @bucket, @key = bucket, key
      @links, @meta = Set.new, {}
      yield self if block_given?
    end

    # Load object data from an HTTP response
    # @param [Hash] response a response from {Riak::Client::HTTPBackend}
    def load(response)
      extract_header(response, "location", :key) {|v| URI.unescape(v.split("/").last) }
      extract_header(response, "content-type", :content_type)
      extract_header(response, "x-riak-vclock", :vclock)
      extract_header(response, "link", :links) {|v| Set.new(Link.parse(v)) }
      extract_header(response, "etag", :etag)
      extract_header(response, "last-modified", :last_modified) {|v| Time.httpdate(v) }
      @meta = response[:headers].inject({}) do |h,(k,v)|
        if k =~ /x-riak-meta-(.*)/
          h[$1] = v
        end
        h
      end
      @conflict = response[:code].try(:to_i) == 300 && content_type =~ /multipart\/mixed/
      @siblings = nil
      @data = deserialize(response[:body]) if response[:body].present?
      self
    end

    # Load object data from a map/reduce response values.
    # @param [Hash] response a response from {Riak::MapReduce}
    # This method is used by generate_from_map_reduce to instantiate the necessary
    # objects.
    #
    # :nodoc:
    #
    # An example of values:
    #
    # {"metadata"=>
    #   {"Links"=>[["users", "A2cbUQ2KEMbeyWGtdz97LoTi1DN", "user"]],
    #    "X-Riak-VTag"=>"5bnavU3rrubcxLI8EvFXhB",
    #    "content-type"=>"application/json",
    #    "X-Riak-Last-Modified"=>"Mon, 12 Jul 2010 21:37:43 GMT",
    #    "X-Riak-Meta"=>{"X-Riak-Meta-King-Of-Robots"=>"I"}},
    #  "data"=>
    #   "{\"email\":\"misaka@pobox.com\",\"confirmed\":true,\"_type\":\"User\"}"}
    def load_from_map_reduce(response)
      metadata = response['metadata']
      extract_if_present(metadata, 'X-Riak-VTag', :etag)
      extract_if_present(metadata, 'content-type', :content_type)
      extract_if_present(metadata, 'X-Riak-Last-Modified', :last_modified) { |v| Time.httpdate( v ) }
      extract_if_present(metadata, 'Links', :links) do |links|
        Set.new( links.map { |l| Link.new("#{@bucket.client.prefix}#{l[0]}/#{l[1]}", l[2]) } )
      end
      extract_if_present(metadata, 'X-Riak-Meta', :meta) do |meta|
        Hash[
          meta.map do |k,v|
            [k.sub(%r{^x-riak-meta-}i, ''), [v]]
          end
        ]
      end
      extract_if_present(response, 'data', :data) { |v| deserialize(v) }
      self
    end

    # HTTP header hash that will be sent along when storing the object
    # @return [Hash] hash of HTTP Headers
    def store_headers
      {}.tap do |hash|
        hash["Content-Type"] = @content_type
        hash["X-Riak-Vclock"] = @vclock if @vclock
        unless @links.blank?
          hash["Link"] = @links.reject {|l| l.rel == "up" }.map(&:to_s).join(", ")
        end
        unless @meta.blank?
          @meta.each do |k,v|
            hash["X-Riak-Meta-#{k}"] = v.to_s
          end
        end
      end
    end

    # HTTP header hash that will be sent along when reloading the object
    # @return [Hash] hash of HTTP headers
    def reload_headers
      {}.tap do |h|
        h['If-None-Match'] = @etag if @etag.present?
        h['If-Modified-Since'] = @last_modified.httpdate if @last_modified.present?
      end
    end

    # Store the object in Riak
    # @param [Hash] options query parameters
    # @option options [Fixnum] :r the "r" parameter (Read quorum for the implicit read performed when validating the store operation)
    # @option options [Fixnum] :w the "w" parameter (Write quorum)
    # @option options [Fixnum] :dw the "dw" parameter (Durable-write quorum)
    # @option options [Boolean] :returnbody (true) whether to return the result of a successful write in the body of the response. Set to false for fire-and-forget updates, set to true to immediately have access to the object's stored representation.
    # @return [Riak::RObject] self
    # @raise [ArgumentError] if the content_type is not defined
    def store(options={})
      raise ArgumentError, t("content_type_undefined") unless @content_type.present?
      params = {:returnbody => true}.merge(options)
      method, codes, path = @key.present? ? [:put, [200,204,300], "#{escape(@bucket.name)}/#{escape(@key)}"] : [:post, 201, escape(@bucket.name)]
      response = @bucket.client.http.send(method, codes, @bucket.client.prefix, path, params, serialize(data), store_headers)
      load(response)
    end

    # Reload the object from Riak.  Will use conditional GETs when possible.
    # @param [Hash] options query parameters
    # @option options [Fixnum] :r the "r" parameter (Read quorum)
    # @option options [Boolean] :force will force a reload request if the vclock is not present, useful for reloading the object after a store (not passed in the query params)
    # @return [Riak::RObject] self
    def reload(options={})
      force = options.delete(:force)
      return self unless @key && (@vclock || force)
      codes = @bucket.allow_mult ? [200,300,304] : [200,304]
      response = @bucket.client.http.get(codes, @bucket.client.prefix, escape(@bucket.name), escape(@key), options, reload_headers)
      load(response) unless response[:code] == 304
      self
    end

    alias :fetch :reload

    # Delete the object from Riak and freeze this instance.  Will work whether or not the object actually
    # exists in the Riak database.
    def delete(options={})
      return if key.blank?
      @bucket.delete(key, options)
      freeze
    end

    # Returns sibling objects when in conflict.
    # @return [Array<RObject>] an array of conflicting sibling objects for this key
    # @return [self] this object when not in conflict
    def siblings
      return self unless conflict?
      @siblings ||= Multipart.parse(data, Multipart.extract_boundary(content_type)).map do |part|
        RObject.new(self.bucket, self.key) do |sibling|
          sibling.load(part)
          sibling.vclock = vclock
        end
      end
    end

    # @return [true,false] Whether this object has conflicting sibling objects (divergent vclocks)
    def conflict?
      @conflict.present?
    end

    # Serializes the internal object data for sending to Riak. Differs based on the content-type.
    # This method is called internally when storing the object.
    # Automatically serialized formats:
    # * JSON (application/json)
    # * YAML (text/yaml)
    # * Marshal (application/octet-stream if meta['ruby-serialization'] == "Marshal")
    # @param [Object] payload the data to serialize
    def serialize(payload)
      return payload if IO === payload
      case @content_type
      when /json/
        ActiveSupport::JSON.encode(payload)
      when /yaml/
        YAML.dump(payload)
      when "application/octet-stream"
        if @meta['ruby-serialization'] == "Marshal"
          Marshal.dump(payload)
        else
          payload.to_s
        end
      else
        payload.to_s
      end
    end

    # Deserializes the internal object data from a Riak response. Differs based on the content-type.
    # This method is called internally when loading the object.
    # Automatically deserialized formats:
    # * JSON (application/json)
    # * YAML (text/yaml)
    # * Marshal (application/octet-stream if meta['ruby-serialization'] == "Marshal")
    # @param [String] body the serialized response body
    def deserialize(body)
      case @content_type
      when /json/
        ActiveSupport::JSON.decode(body)
      when /yaml/
        YAML.load(body)
      when "application/octet-stream"
        if @meta['ruby-serialization'] == "Marshal"
          Marshal.load(body)
        else
          body
        end
      else
        body
      end
    end

    # @return [String] A representation suitable for IRB and debugging output
    def inspect
      "#<#{self.class.name} #{url} [#{@content_type}]:#{@data.inspect}>"
    end

    # Walks links from this object to other objects in Riak.
    def walk(*params)
      specs = WalkSpec.normalize(*params)
      response = @bucket.client.http.get(200, @bucket.client.prefix, escape(@bucket.name), escape(@key), specs.join("/"))
      if boundary = Multipart.extract_boundary(response[:headers]['content-type'].first)
        Multipart.parse(response[:body], boundary).map do |group|
          map_walk_group(group)
        end
      else
        []
      end
    end

    # Converts the object to a link suitable for linking other objects to it
    def to_link(tag)
      Link.new(@bucket.client.http.path(@bucket.client.prefix, escape(@bucket.name), escape(@key)).path, tag)
    end

    # Generates a URL representing the object according to the client, bucket and key.
    # If the key is blank, the bucket URL will be returned (where the object will be
    # submitted to when stored).
    def url
      segments = [ @bucket.client.prefix, escape(@bucket.name)]
      segments << escape(@key) if @key
      @bucket.client.http.path(*segments).to_s
    end

    private
    def extract_if_present(hash, key, attribute=nil)
      if hash[key].present?
        attribute ||= key
        value = block_given? ? yield(hash[key]) : hash[key]
        send("#{attribute}=", value)
      end
    end
    
    def extract_header(response, name, attribute=nil, &block)
      extract_if_present(response[:headers], name, attribute) do |value|
        block ? block.call(value[0]) : value[0]
      end
    end

    def map_walk_group(group)
      group.map do |obj|
        if obj[:headers] && obj[:body] && obj[:headers]['location']
          bucket, key = $1, $2 if obj[:headers]['location'].first =~ %r{/.*/(.*)/(.*)$}
          RObject.new(@bucket.client.bucket(bucket, :keys => false), key).load(obj)
        end
      end
    end
  end
end
