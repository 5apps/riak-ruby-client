require 'spec_helper'

if $test_server
  describe Riak::TestServer do
    before do
      @server = $test_server
    end

    after do
      @server.stop
      @server.cleanup
    end

    describe "isolation from and modification of the existing install" do
      before do
        @server.prepare!
        @riak_bin    = "#{@server.temp_dir}/bin/riak"
        @vm_args     = "#{@server.temp_dir}/etc/vm.args"
        @app_config  = "#{@server.temp_dir}/etc/app.config"
      end

      describe "for app.config" do
        it "should create the app.config file in the temporary directory" do
          File.should be_exist(File.expand_path(@app_config))
        end

        it "should be a correct Erlang config" do
          config = File.read(@app_config)
          config[-2..-1].should == '].'
          config[0..0].should == '['
        end

        it "should set the backend to use the test backend" do
          File.readlines(@app_config).should be_any do |line|
            line =~ /\{storage_backend\s*,\s*(.*)\}/ && $1 == "riak_kv_test_backend"
          end
        end

        it "should set the default ports to 9000-9002" do
          config = File.readlines(@app_config)
          config.should be_any do |line|
            line =~ /\{web_port\s*,\s*(.*)\}/ && $1 == "9000"
          end
          config.should be_any do |line|
            line =~ /\{handoff_port\s*,\s*(.*)\}/ && $1 == "9001"
          end
          config.should be_any do |line|
            line =~ /\{pb_port\s*,\s*(.*)\}/ && $1 == "9002"
          end
        end

        it "should set the ring directory to point to the temporary directory" do
          config = File.readlines(@app_config)
          config.should be_any do |line|
            line =~ /\{ring_state_dir\s*,\s*(.*)\}/ && $1 == File.join(@server.temp_dir, "data", "ring")
          end
        end
      end

      describe "for vm.args" do
        it "should create the vm.args file in the temporary directory" do
          File.should be_exist(File.expand_path(@vm_args))
        end

        it "should set a quasi-random node name" do
          File.readlines(@vm_args).should be_any do |line|
            line =~ /^-name (.*)/ && $1 =~ /riaktest\d+@/
          end
        end

        it "should set a quasi-random cookie" do
          File.readlines(@vm_args).should be_any do |line|
            line =~ /^-setcookie (.*)/ && $1 != "riak"
          end
        end
      end

      describe "for the riak script" do
        it "should create the script in the temporary directory" do
          File.should be_exist(File.expand_path(@riak_bin))
        end

        it "should modify the RUNNER_SCRIPT_DIR to point to the temporary directory" do
          File.readlines(@riak_bin).should be_any do |line|
            line =~ /RUNNER_SCRIPT_DIR=(.*)/ && $1 == File.expand_path("#{@server.temp_dir}/bin")

          end
        end

        it "should modify the RUNNER_ETC_DIR to point to the temporary directory" do
          File.readlines(@riak_bin).should be_any do |line|
            line =~ /RUNNER_ETC_DIR=(.*)/ && $1 == File.expand_path("#{@server.temp_dir}/etc")
          end
        end

        it "should modify the RUNNER_USER to point to the current user" do
          File.readlines(@riak_bin).should be_any do |line|
            line =~ /RUNNER_USER=(.*)/ && $1 == (ENV['USER'] || `whoami`)
          end
        end

        it "should modify the RUNNER_LOG_DIR to point to the temporary directory" do
          File.readlines(@riak_bin).should be_any do |line|
            line =~ /RUNNER_LOG_DIR=(.*)/ && $1 == File.expand_path("#{@server.temp_dir}/log")
          end
        end

        it "should modify the RUNNER_BASE_DIR so that it is not relative" do
          File.readlines(@riak_bin).should be_any do |line|
            line =~ /RUNNER_BASE_DIR=(.*)/ && $1.strip != "${RUNNER_SCRIPT_DIR%/*}" && File.directory?($1)
          end
        end

        it "should modify the PIPE_DIR to point to the temporary directory" do
          File.readlines(@riak_bin).should be_any do |line|
            line =~ /PIPE_DIR=(.*)/ &&  $1 == File.expand_path("#{@server.temp_dir}/pipe") && File.directory?($1)
          end
        end
      end
    end

    it "should cleanup the existing config" do
      @server.prepare!
      @server.cleanup
      File.should_not be_directory(@server.temp_dir)
    end

    it "should start Riak in the background" do
      @server.prepare!
      @server.start.should be_true
      @server.should be_started
    end

    it "should stop a started test server" do
      @server.prepare!
      @server.start.should be_true
      @server.stop
      @server.should_not be_started
    end

    it "should recycle the server contents" do
      begin
        @server.prepare!
        @server.start.should be_true

        client = Riak::Client.new(:http_port => 9000)
        obj = client['test_bucket'].new("test_item")
        obj.data = {"data" => "testing"}
        obj.store rescue nil

        @server.recycle
        @server.should be_started
        lambda do
          client['test_bucket']['test_item']
        end.should raise_error(Riak::FailedRequest)
      ensure
        @server.stop
      end
    end
  end
end
