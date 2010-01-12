require File.join(File.dirname(__FILE__), "spec_helper")

describe Riak::Bucket do
  before :each do
    @client = Riak::Client.new
    @bucket = Riak::Bucket.new(@client, "foo")
  end

  def do_load(overrides={})
    @bucket.load({
                   :body => '{"props":{"name":"foo","allow_mult":false,"big_vclock":50,"chash_keyfun":{"mod":"riak_util","fun":"chash_std_keyfun"},"linkfun":{"mod":"jiak_object","fun":"mapreduce_linkfun"},"n_val":3,"old_vclock":86400,"small_vclock":10,"young_vclock":20},"keys":["bar"]}',
                   :headers => {
                     "vary" => ["Accept-Encoding"],
                     "server" => ["MochiWeb/1.1 WebMachine/1.5.1 (hack the charles gibson)"],
                     "link" => ['</raw/foo/bar>; riaktag="contained"'],
                     "date" => ["Tue, 12 Jan 2010 15:30:43 GMT"],
                     "content-type" => ["application/json"],
                     "content-length" => ["257"]
                   }
                 }.merge(overrides))
  end


  describe "when initializing" do
    it "should require a client and a name" do
      lambda { Riak::Bucket.new }.should raise_error
      lambda { Riak::Bucket.new(@client) }.should raise_error
      lambda { Riak::Bucket.new("foo") }.should raise_error
      lambda { Riak::Bucket.new("foo", @client) }.should raise_error
      lambda { Riak::Bucket.new(@client, "foo") }.should_not raise_error
    end

    it "should set the client and name attributes" do
      bucket = Riak::Bucket.new(@client, "foo")
      bucket.client.should == @client
      bucket.name.should == "foo"
    end
  end

  describe "when loading data from an HTTP response" do
    it "should load the bucket properties from the response body" do
      do_load
      @bucket.props.should == {"name"=>"foo","allow_mult" => false,"big_vclock" => 50,"chash_keyfun" => {"mod" =>"riak_util","fun"=>"chash_std_keyfun"},"linkfun"=>{"mod"=>"jiak_object","fun"=>"mapreduce_linkfun"},"n_val"=>3,"old_vclock"=>86400,"small_vclock"=>10,"young_vclock"=>20}
    end

    it "should load the keys from the response body" do
      do_load
      @bucket.keys.should == ["bar"]
    end

    it "should raise an error for a response that is not JSON" do
      lambda do
        do_load(:headers => {"content-type" => ["text/plain"]})
      end.should raise_error(Riak::InvalidResponse)
    end
  end

  describe "accessing keys" do
    before :each do
      @http = mock("HTTPBackend")
      @client.should_receive(:http).and_return(@http)
      @http.should_receive(:get).with(200, "foo", {:props=>false}, {}).and_return({:headers => {"content-type" => ["application/json"]}, :body => '{"keys":["bar"]}'})

    end
    
    it "should load the keys if not present" do
      @bucket.keys.should == ["bar"]
    end

    it "should allow reloading of the keys" do
      do_load # Ensures they're already loaded
      @bucket.keys(:reload => true).should == ["bar"]
    end

    it "should allow streaming keys through block" do
      pending "Needs support in the raw_http_interface"
    end
  end
end
