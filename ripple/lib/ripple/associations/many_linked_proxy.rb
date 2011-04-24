# Copyright 2010-2011 Sean Cribbs and Basho Technologies, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'ripple/associations/proxy'
require 'ripple/associations/many'
require 'ripple/associations/linked'

module Ripple
  module Associations
    class ManyLinkedProxy < Proxy
      include Many
      include Linked

      def <<(value)
        load_target
        new_target = @target.concat(Array(value))
        replace new_target
        self
      end

      def delete(value)
        load_target
        @target.delete(value)
        replace @target
        self
      end

      protected
      def find_target
        robjects.map {|robj| klass.send(:instantiate, robj) }
      end
    end
  end
end
