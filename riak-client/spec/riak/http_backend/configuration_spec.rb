require 'spec_helper'

describe Riak::Client::HTTPBackend::Configuration do
  let(:client){ Riak::Client.new }
  subject { Riak::Client::HTTPBackend.new(client) }
  let(:uri){ URI.parse("http://127.0.0.1:8098/") }

  context "generating resource URIs" do
    context "when using the old scheme" do
      before { subject.should_receive(:get).with(200, uri).and_return(:headers => {'link' => ['</riak>; rel="riak_kv_wm_raw", </ping>; rel="riak_kv_wm_ping", </stats>; rel="riak_kv_wm_stats", </mapred>; rel="riak_kv_wm_mapred"']}) }

      it "should generate a ping path" do
        url = subject.ping_path
        url.should be_kind_of(URI)
        url.path.should == '/ping'
      end
      
      it "should generate a stats path" do
        url = subject.stats_path
        url.should be_kind_of(URI)
        url.path.should == '/stats'
      end
      
      it "should generate a mapred path" do
        url = subject.mapred_path :chunked => true
        url.should be_kind_of(URI)
        url.path.should == '/mapred'
        url.query.should == "chunked=true"
      end
      
      it "should generate a bucket list path" do
        url = subject.bucket_list_path
        url.should be_kind_of(URI)
        url.path.should == '/riak'
        url.query.should == 'buckets=true'
      end
      
      it "should generate a bucket properties path" do
        url = subject.bucket_properties_path('test ')
        url.should be_kind_of(URI)
        url.path.should == '/riak/test%20'
        url.query.should == "keys=false&props=true"
      end
      
      it "should generate a key list path" do
        url = subject.key_list_path('test ')
        url.should be_kind_of(URI)
        url.path.should == '/riak/test%20'
        url.query.should == 'keys=true&props=false'
        url = subject.key_list_path('test ', :keys => :stream)
        url.path.should == '/riak/test%20'
        url.query.should == 'keys=stream&props=false'
      end
      
      it "should generate an object path" do
        url = subject.object_path('test ', 'object/', :r => 3)
        url.should be_kind_of(URI)
        url.path.should == '/riak/test%20/object%2F'
        url.query.should == 'r=3'
      end
      
      it "should generate a link-walking path" do
        url = subject.link_walk_path('test ', 'object/', [Riak::WalkSpec.new(:bucket => 'foo')])
        url.should be_kind_of(URI)
        url.path.should == '/riak/test%20/object%2F/foo,_,_'
      end
    end
    
    context "when using the new scheme" do
            before { subject.should_receive(:get).with(200, uri).and_return(:headers => {'link' => ['</buckets>; rel="riak_kv_wm_buckets", </ping>; rel="riak_kv_wm_ping", </stats>; rel="riak_kv_wm_stats", </mapred>; rel="riak_kv_wm_mapred"']}) }

      it "should generate a ping path" do
        url = subject.ping_path
        url.should be_kind_of(URI)
        url.path.should == '/ping'
      end
      
      it "should generate a stats path" do
        url = subject.stats_path
        url.should be_kind_of(URI)
        url.path.should == '/stats'
      end
      
      it "should generate a mapred path" do
        url = subject.mapred_path :chunked => true
        url.should be_kind_of(URI)
        url.path.should == '/mapred'
        url.query.should == "chunked=true"
      end
      
      it "should generate a bucket list path" do
        url = subject.bucket_list_path
        url.should be_kind_of(URI)
        url.path.should == '/buckets'
        url.query.should == 'buckets=true'
      end
      
      it "should generate a bucket properties path" do
        url = subject.bucket_properties_path('test ')
        url.should be_kind_of(URI)
        url.path.should == '/buckets/test%20/props'
        url.query.should be_nil
      end
      
      it "should generate a key list path" do
        url = subject.key_list_path('test ')
        url.should be_kind_of(URI)
        url.path.should == '/buckets/test%20/keys'
        url.query.should == 'keys=true'
        url = subject.key_list_path('test ', :keys => :stream)
        url.path.should == '/buckets/test%20/keys'
        url.query.should == 'keys=stream'
      end
      
      it "should generate an object path" do
        url = subject.object_path('test ', 'object/', :r => 3)
        url.should be_kind_of(URI)
        url.path.should == '/buckets/test%20/keys/object%2F'
        url.query.should == 'r=3'
      end
      
      it "should generate a link-walking path" do
        url = subject.link_walk_path('test ', 'object/', [Riak::WalkSpec.new(:bucket => 'foo')])
        url.should be_kind_of(URI)
        url.path.should == '/buckets/test%20/keys/object%2F/foo,_,_'
      end
    end
  end

  it "should memoize the server config" do
    subject.should_receive(:get).with(200, uri).once.and_return(:headers => {'link' => ['</riak>; rel="riak_kv_wm_link_walker",</mapred>; rel="riak_kv_wm_mapred",</ping>; rel="riak_kv_wm_ping",</riak>; rel="riak_kv_wm_raw",</stats>; rel="riak_kv_wm_stats"']})
    subject.send(:riak_kv_wm_link_walker).should == "/riak"
    subject.send(:riak_kv_wm_raw).should == "/riak"
  end

  {
    :riak_kv_wm_raw => :prefix,
    :riak_kv_wm_link_walker => :prefix,
    :riak_kv_wm_mapred => :mapred
  }.each do |resource, alternate|
    it "should detect the #{resource} resource from the configuration URL" do
      subject.should_receive(:get).with(200, uri).and_return(:headers => {'link' => [%Q{</path>; rel="#{resource}"}]})
      subject.send(resource).should == "/path"
    end
    it "should fallback to client.#{alternate} if the #{resource} resource is not found" do
      subject.should_receive(:get).with(200, uri).and_return(:headers => {'link' => ['</>; rel="top"']})
      subject.send(resource).should == client.send(alternate)
    end
    it "should fallback to client.#{alternate} if request fails" do
      subject.should_receive(:get).with(200, uri).and_raise(Riak::HTTPFailedRequest.new(:get, 200, 404, {}, ""))
      subject.send(resource).should == client.send(alternate)
    end
  end

  {
    :riak_kv_wm_ping => "/ping",
    :riak_kv_wm_stats => "/stats"
  }.each do |resource, default|
    it "should detect the #{resource} resource from the configuration URL" do
      subject.should_receive(:get).with(200, uri).and_return(:headers => {'link' => [%Q{</path>; rel="#{resource}"}]})
      subject.send(resource).should == "/path"
    end
    it "should fallback to #{default.inspect} if the #{resource} resource is not found" do
      subject.should_receive(:get).with(200, uri).and_return(:headers => {'link' => ['</>; rel="top"']})
      subject.send(resource).should == default
    end
    it "should fallback to #{default.inspect} if request fails" do
      subject.should_receive(:get).with(200, uri).and_raise(Riak::HTTPFailedRequest.new(:get, 200, 404, {}, ""))
      subject.send(resource).should == default
    end
  end
end
