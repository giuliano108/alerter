require 'rubygems'
require 'bundler/setup'
require 'haml'
require 'ostruct'
require 'sinatra' unless defined?(Sinatra)
require 'sinatra/reloader' if development?
require 'ruby-debug' if development?
require 'data_mapper'
require 'date'
require 'json'
require 'pony'
require 'active_support/time'
require 'ice_cube'

YAML::ENGINE.yamler='syck' # FIXME: this is to avoid ASCII-8BIT to be dumped as binary

require File.join(File.dirname(__FILE__), 'exceptions')
require File.join(File.dirname(__FILE__), 'tags')

configure do
    set :views, "#{File.dirname(__FILE__)}/views"
end

configure(:development) do 
    DataPath = "#{File.dirname(__FILE__)}/data"
    DataMapper.setup(:default, "sqlite3://#{DataPath}/development.db")
    require File.join(File.dirname(__FILE__), 'models')
    PonyOptions = OpenStruct.new(
        :via => :smtp,
        :options => {
            :address => 'smtp.forward.co.uk',
            :enable_starttls_auto => false
        }
    )

    also_reload File.join(File.dirname(__FILE__), 'tags.rb')
end

configure(:production) do 
    DataPath = "#{File.dirname(__FILE__)}/data"
    DataMapper.setup(:default, "mysql://alerter:xxxx@localhost/alerter")
    require File.join(File.dirname(__FILE__), 'models')
    PonyOptions = OpenStruct.new(
        :via => :sendmail,
        :options => {
        }
    )
end

configure do
    class Mailer
        def send(from, to, subject, body)
            Pony.mail(:from => from,
                      :to => to,
                      :via => PonyOptions.via,
                      :via_options => PonyOptions.options,
                      :subject => subject,
                      :body => body)
        end
    end
    set :mailer, Mailer.new # Can't use lambda/Proc (would get called upon reading setting.mailer)
end

SiteConfig = OpenStruct.new(
             :title => 'Alerter',
             :author => 'Giuliano Cioffi',
           )
