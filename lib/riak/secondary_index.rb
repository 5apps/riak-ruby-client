require 'riak/index_collection'
module Riak
  class SecondaryIndex
    include Util::Translation
    include Client::FeatureDetection

    # Create a Riak Secondary Index operation
    # @param [Bucket] the {Riak::Bucket} we'll query against
    # @param [String] the index name
    # @param [String,Integer,Range<String,Integer>] a single value or
    #   range of values to query for
    def initialize(bucket, index, query, options={})
      @bucket = bucket
      @client = @bucket.client
      @index = index
      @query = query
      @options = options

      validate_options
    end

    # Start the 2i fetch operation
    def fetch
    end

    # Get the array of matched keys
    def keys
      @collection ||=
        @client.backend do |b|
          b.get_index @bucket, @index, @query, @options
        end
    end

    # Get the array of values
    def values
      @values ||= @bucket.get_many(self.keys).values
    end

    # Get a new SecondaryIndex fetch for the next page
    def next_page
      raise t('index.no_next_page') unless keys.continuation

      self.class.new(@bucket, 
                     @index, 
                     @query, 
                     @options.merge(:continuation => keys.continuation))
    end

    private
    def validate_options
      raise t('index.pagination_not_available') if paginated? && !index_pagination?
      raise t('index.return_terms_not_available') if @options[:return_terms] && !index_return_terms?

      # TODO: uncomment that last part when implementing streaming
      raise t('index.streaming_not_available') if @options[:stream] # && !index_streaming
    end

    def paginated?
      @options[:continuation] || @options[:max_results]
    end
  end
end
