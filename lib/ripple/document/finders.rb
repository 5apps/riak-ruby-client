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
require 'ripple'

module Ripple
  module Document
    module Finders
      extend ActiveSupport::Concern

      module ClassMethods
        def find(*args)
          args.flatten!
          return [] if args.length == 0
          return find_one(args.first) if args.length == 1
          args.map {|key| find_one(key) }
        end

        def all
          if block_given?
            bucket.keys do |key|
              yield find_one(key)
            end
            []
          else
            bucket.keys.inject([]) {|acc, k| obj = find_one(k); obj ? acc << obj : acc }
          end
        end

        private
        def find_one(key)
          instantiate(bucket.get(key))
        rescue Riak::FailedRequest => fr
          return nil if fr.code.to_i == 404
          raise fr
        end

        def instantiate(robject)
          klass = robject.data['_type'].constantize rescue self
          klass.new(robject.data.merge('key' => robject.key))
        end
      end
    end
  end
end
