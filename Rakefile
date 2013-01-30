require 'rubygems'
require 'bundler/setup'

task :default => :test

task :environment do
  require File.join(File.dirname(__FILE__), 'environment')
  puts "Current environment: " + Sinatra::Base.environment.to_s
end
