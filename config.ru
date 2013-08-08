$LOAD_PATH.unshift File.dirname(__FILE__)
require 'alerter/base'

$stdout.sync = true

Alerter::preconfig File.dirname(__FILE__)
Alerter::SinatraRoot = File.dirname(__FILE__)
Alerter::ApplicationTitle = 'Alerter'

require 'alerter/web'
run Alerter::Web::App
