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
require File.expand_path("../../../spec_helper", __FILE__)

describe Ripple::EmbeddedDocument::Persistence do
  before :all do
    Object.module_eval { class Address; include Ripple::EmbeddedDocument; end }
  end

  before :each do
    @root = mock("root document")
    @root.stub!(:new?).and_return(true)
    @addr = Address.new
    @addr._root_document = @root
  end

  it "should delegate new? to the root document" do
    @root.should_receive(:new?).and_return(true)
    @addr.should be_new
  end

  it "should delegate save to the root document" do
    @root.should_receive(:save).and_return(true)
    @addr.save.should be_true
  end
  
  it "should delegate save! to the root document" do
    @root.should_receive(:save!).and_return(true)
    @addr.save!.should be_true
  end
  
  it "should know the document its embedded in"

  after :all do
    Object.send(:remove_const, :Address)
  end
end
