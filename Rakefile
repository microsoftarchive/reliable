require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :console do
  $LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
  ENV["RELIABLE_TIMEOUT"] = "1"
  ENV["RELIABLE_TIME_TRAVEL_DELAY"] = "1"
  ENV["REDIS_URI"] = "redis://127.0.0.1:6379/0"
  require 'reliable'
  require 'irb'
  ARGV.clear
  IRB.start
end
