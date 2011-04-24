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

require 'active_support/concern'

module Ripple
  module AttributeMethods
    module Read
      extend ActiveSupport::Concern

      included do
        attribute_method_suffix ""
      end

      def [](attr_name)
        attribute(attr_name)
      end

      private
      def attribute(attr_name)
        if @attributes.include?(attr_name)
          @attributes[attr_name]
        else
          nil
        end
      end
    end
  end
end
