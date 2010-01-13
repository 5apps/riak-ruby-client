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
end
