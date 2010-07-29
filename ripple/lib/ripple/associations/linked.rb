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
  module Associations
    module Linked
      # TODO: decide whether to save owner automatically
      def replace(value)
        @owner.robject.links -= links
        Array(value).compact.each do |doc|
          @owner.robject.links << doc.robject.to_link(@reflection.name.to_s)
        end
        loaded
        @target = value
      end

      protected
      def links
        @owner.robject.links.select {|l| l.tag == @reflection.name.to_s }
      end

      def robjects
        @owner.robject.walk(:tag => @reflection.name.to_s).first
      rescue
        []
      end
    end
  end
end
