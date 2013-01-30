require "bundler/capistrano"
require "rvm/capistrano"
load 'deploy'

set :application, "alerter"
set :branch, "master"
set :deploy_to, "/home/deploy/alerter"
set :deploy_via, :remote_cache
set :keep_releases, 5
set :normalize_asset_timestamps, false
set :repository,  "git@putyourrepohere"
set :scm, "git"
set :use_sudo, false
set :user, "deploy"
ssh_options[:forward_agent] = true
default_run_options[:pty] = true


role :web, "10.1.2.3"

namespace :deploy do
  desc "Start the Thin processes"
  task :start do
    run "cd #{deploy_to}/current; bundle exec thin start -C thin.yml"
  end

  desc "Stop the Thin processes"
  task :stop do
    run "cd #{deploy_to}/current; bundle exec thin stop -C thin.yml"
  end

  desc "Restart the Thin processes"
  task :restart do
    run "cd #{deploy_to}/current; bundle exec thin restart -C thin.yml"
  end
end
