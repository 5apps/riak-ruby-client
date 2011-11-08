require 'ripple/translation'
require 'riak/cluster'
require 'pp'

namespace :riak do
  task :cluster_created => :rails_env do
    fail Ripple::Translator.t('cluster_not_created') unless cluster.exist?
  end

  desc "Starts the Riak cluster for the current environment"
  task :start => :cluster_created do
    cluster.start
  end

  desc "Stops the Riak cluster for the current environment"
  task :stop => :cluster_created do
    cluster.stop
  end

  desc "Creates a Riak cluster for the current environment in db/, e.g. db/development"
  task :create => :rails_env do
    cluster.create
  end

  desc "Destroys and recreates the cluster for the current environment."
  task :reset => ['riak:destroy', 'riak:setup']

  desc "Creates the Riak cluster and loads the seed data."
  task :setup => ["riak:create", "db:seed"]

  desc "Destroys the generated Riak cluster for the current environment."
  task :destroy => :rails_env do
    cluster.destroy
  end

  desc "Drops data only from the Riak cluster for the current environment."
  task :drop => :cluster_created do
    cluster.drop
  end

  namespace :create do
    desc "Creates Riak clusters for all environments defined in config/ripple.yml"
    task :all do
      load_config.each do |env, config|
        cluster(env.to_s, config).create
      end
    end
  end

  namespace :drop do
    desc "Drops data Riak clusters for all environments defined in config/ripple.yml"
    task :all do
      load_config.each do |env, config|
        c = cluster(env.to_s, config)
        warn Ripple::Translator.t('cluster_not_created') unless c.exist?
        c.drop
      end
    end
  end
end

namespace :db do
  task :create => "riak:create"
  namespace(:create){ task :all => "riak:create:all" }
  task :drop => "riak:drop"
  namespace(:drop) { task :all => "riak:drop:all" }
  task :setup => "riak:setup"
  task :reset => "riak:reset"
  task seed: ['riak:start', 'environment'] do
    Rails.application.load_seed
  end
end

def load_config
  file = Rails.root + "config/ripple.yml"
  raise Ripple::MissingConfiguration, file.to_s unless file.exist?
  YAML.load(ERB.new(file.read).result).with_indifferent_access
end

def cluster(environment=nil, config=nil)
  environment ||= Rails.env
  config ||= load_config[environment]
  root = Rails.root + "db" + environment.to_s
  # TODO: We need to deal with multiple hosts and client ports
  Riak::Cluster.new(config.merge(:root => root.to_s).with_indifferent_access)
end
