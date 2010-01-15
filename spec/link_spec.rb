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
require File.join(File.dirname(__FILE__), 'spec_helper')

describe Riak::Link do
  describe "parsing a link header" do
    it "should create Link objects from the data" do
      result = Riak::Link.parse('</raw/foo/bar>; rel="tag", </raw/foo>; rel="up"')
      result.should be_kind_of(Array)
      result.should be_all {|i| Riak::Link === i }
    end

    it "should set the url and rel parameters properly" do
      result = Riak::Link.parse('</raw/foo/bar>; rel="tag", </raw/foo>; rel="up"')
      result[0].url.should == "/raw/foo/bar"
      result[0].rel.should == "tag"
      result[1].url.should == "/raw/foo"
      result[1].rel.should == "up"
    end
  end

  it "should convert to a string appropriate for use in the Link header" do
    Riak::Link.new("/raw/foo", "up").to_s.should == '</raw/foo>; rel="up"'
    Riak::Link.new("/raw/foo/bar", "next").to_s.should == '</raw/foo/bar>; rel="next"'
  end
end
