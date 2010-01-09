require 'riak'

module Riak
  class Client
    class HTTPBackend
      # The Riak::Client that uses this backend
      attr_reader :client

      # Create an HTTPBackend for the Riak::Client.
      # @param [Client] client the client
      def initialize(client)
        raise ArgumentError, "Riak::Client instance required" unless Client === client
        @client = client
      end

      # Default header hash sent with every request, based on settings in the client
      # @return [Hash] headers that will be merged with user-specified headers on every request
      def default_headers
        {
          "X-Riak-ClientId" => @client.client_id
        }
      end

      # Performs a HEAD request to the specified resource on the Riak server.
      # @param [Fixnum] expect the expected HTTP response code from Riak
      # @param [String, Array<String,Hash>] resource a relative path or array of path segments and optional query params Hash that will be joined to the root URI
      # @overload head(expect, *resource)
      # @overload head(expect, *resource, headers)
      #   Send the request with custom headers
      #   @param [Hash] headers custom headers to send with the request
      # @return [Hash] response data, containing only the :headers key
      # @raise [FailedRequest] if the response code doesn't match the expected response
      def head(expect, *resource)
        headers = default_headers.merge(resource.extract_options!)
        verify_path!(resource)
        perform(:head, path(*resource), headers, expect)
      end

      # Performs a GET request to the specified resource on the Riak server.
      # @param [Fixnum] expect the expected HTTP response code from Riak
      # @param [String, Array<String,Hash>] resource a relative path or array of path segments and optional query params Hash that will be joined to the root URI
      # @overload get(expect, *resource)
      # @overload get(expect, *resource, headers)
      #   Send the request with custom headers
      #   @param [Hash] headers custom headers to send with the request
      # @overload get(expect, *resource, headers={})
      #   Stream the response body through the supplied block
      #   @param [Hash] headers custom headers to send with the request
      #   @yield [chunk] yields successive chunks of the response body as strings
      #   @return [Hash] response data, containing only the :headers key
      # @return [Hash] response data, containing :headers and :body keys
      # @raise [FailedRequest] if the response code doesn't match the expected response
      def get(expect, *resource, &block)
        headers = default_headers.merge(resource.extract_options!)
        verify_path!(resource)
        perform(:get, path(*resource), headers, expect, &block)
      end

      # Performs a PUT request to the specified resource on the Riak server.
      # @param [Fixnum] expect the expected HTTP response code from Riak
      # @param [String, Array<String,Hash>] resource a relative path or array of path segments and optional query params Hash that will be joined to the root URI
      # @param [String] body the request body to send to the server
      # @overload put(expect, *resource, body)
      # @overload put(expect, *resource, body, headers)
      #   Send the request with custom headers
      #   @param [Hash] headers custom headers to send with the request
      # @overload put(expect, *resource, body, headers={})
      #   Stream the response body through the supplied block
      #   @param [Hash] headers custom headers to send with the request
      #   @yield [chunk] yields successive chunks of the response body as strings
      #   @return [Hash] response data, containing only the :headers key
      # @return [Hash] response data, containing :headers and :body keys
      # @raise [FailedRequest] if the response code doesn't match the expected response
      def put(expect, *resource, &block)
        headers = default_headers.merge(resource.extract_options!)
        uri, data = verify_path_and_body!(resource)
        perform(:put, path(*uri), headers, expect, data, &block)
      end

      # Performs a POST request to the specified resource on the Riak server.
      # @param [Fixnum] expect the expected HTTP response code from Riak
      # @param [String, Array<String>] resource a relative path or array of path segments that will be joined to the root URI
      # @param [String] body the request body to send to the server
      # @overload post(expect, *resource, body)
      # @overload post(expect, *resource, body, headers)
      #   Send the request with custom headers
      #   @param [Hash] headers custom headers to send with the request
      # @overload post(expect, *resource, body, headers={})
      #   Stream the response body through the supplied block
      #   @param [Hash] headers custom headers to send with the request
      #   @yield [chunk] yields successive chunks of the response body as strings
      #   @return [Hash] response data, containing only the :headers key
      # @return [Hash] response data, containing :headers and :body keys
      # @raise [FailedRequest] if the response code doesn't match the expected response
      def post(expect, *resource, &block)
        headers = default_headers.merge(resource.extract_options!)
        uri, data = verify_path_and_body!(resource)
        perform(:post, path(*uri), headers, expect, data, &block)
      end

      # Performs a DELETE request to the specified resource on the Riak server.
      # @param [Fixnum] expect the expected HTTP response code from Riak
      # @param [String, Array<String,Hash>] resource a relative path or array of path segments and optional query params Hash that will be joined to the root URI
      # @overload delete(expect, *resource)
      # @overload delete(expect, *resource, headers)
      #   Send the request with custom headers
      #   @param [Hash] headers custom headers to send with the request
      # @overload delete(expect, *resource, headers={})
      #   Stream the response body through the supplied block
      #   @param [Hash] headers custom headers to send with the request
      #   @yield [chunk] yields successive chunks of the response body as strings
      #   @return [Hash] response data, containing only the :headers key
      # @return [Hash] response data, containing :headers and :body keys
      # @raise [FailedRequest] if the response code doesn't match the expected response
      def delete(expect, *resource, &block)
        headers = default_headers.merge(resource.extract_options!)
        verify_path!(resource)
        perform(:delete, path(*resource), headers, expect, &block)
      end

      # @return [URI] The calculated root URI for the Riak HTTP endpoint
      def root_uri
        URI.join("http://#{@client.host}:#{@client.port}", @client.prefix)
      end

      # Calculates an absolute URI from a relative path specification
      # @param [Array<String,Hash>] segments a relative path or sequence of path segments and optional query params Hash that will be joined to the root URI
      # @return [URI] an absolute URI for the resource
      def path(*segments)
        query = segments.extract_options!.to_param
        root_uri.merge(segments.join("/").gsub(/\/+/, "/").sub(/^\//, '')).tap do |uri|
          uri.query = query if query.present?
        end
      end

      # Verifies that both a resource path and body are present in the arguments
      # @param [Array] args the arguments to verify
      # @raise [ArgumentError] if the body or resource is missing, or if the body is not a String
      def verify_path_and_body!(args)
        body = args.pop
        begin
          verify_path!(args)
        rescue ArgumentError
          raise ArgumentError, "You must supply both a resource path and a body."
        end

        raise ArgumentError, "Request body must be a string." unless String === body
        [args, body]
      end

      # Verifies that the specified resource is valid
      # @param [String, Array] resource the resource specification
      # @raise [ArgumentError] if the resource path is too short
      def verify_path!(resource)
        raise ArgumentError, "Resource path too short" if Array(resource).flatten.empty?
      end

      # @abstract Subclasses must implement this internal method to perform HTTP requests
      #           according to the API of their HTTP libraries.
      # @param [Symbol] method one of :head, :get, :post, :put, :delete
      # @param [URI] uri the HTTP URI to request
      # @param [Hash] headers headers to send along with the request
      # @param [Fixnum] expect the expected response code
      # @param [optional, String] body the PUT or POST request body
      # @return [Hash] response data, containing :headers and :body keys. Only :headers should be present when the body is streamed or the method is :head.
      # @yield [chunk] if the method is not :head, successive chunks of the response body will be yielded as strings
      # @raise [NotImplementedError] if a subclass does not implement this method
      def perform(method, uri, headers, expect, body=nil)
        raise NotImplementedError
      end
    end
  end
end
