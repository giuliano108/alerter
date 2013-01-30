require File.join(File.dirname(__FILE__), 'application')

set :run, false

# Dump every to the terminal if we're in development.
# This way we can break into the debugger from the code.
if !Sinatra::Application.development?
  FileUtils.mkdir_p 'log' unless File.exists?('log')
  log = File.new("log/sinatra.log", "a+")
  log.sync = true
  $stdout.reopen(log)
  $stderr.reopen(log)
end

run Sinatra::Application
