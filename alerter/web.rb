require 'yaml'
require 'sinatra/base'
require 'alerter/exceptions'
require 'alerter/mailer'
require 'alerter/tags'

module Alerter::Web
    $0 = self.name
    Alerter::dm_setup

    YAML::ENGINE.yamler='syck' # FIXME: this is to avoid ASCII-8BIT to be dumped as binary

    class App < Sinatra::Base

        configure :production, :development do
            enable :logging
            set :root, Alerter::SinatraRoot
            set :views, File.join(Alerter::SinatraRoot,'views')
            set :mailer, Alerter::Mailer.new
        end

        configure :development do
            require 'sinatra/reloader'
            register Sinatra::Reloader
        end

        helpers do
            def get_title
                Alerter::ApplicationTitle
            end
        end

        error do
            e = request.env['sinatra.error']
            Kernel.puts e.backtrace.join("\n")
            'Application error'
        end

        def get_url(request)
            "#{request.scheme}://#{request.host}:#{request.port}"
        end

        # root page
        get '/' do
            @submissions = Submission.all(:order => [:submitted_at.desc])
            haml :root
        end

        Alerter::Tags.set_environment Alerter[:environment].to_sym

        Alerter::Tags.handlers.each do |tag, handler|
            # Usage:
            # tail whatever.log | curl -s -X PUT http://1.1.1.1:9292/tag/whatever --data-binary @-
            put "/#{tag.to_s}/:param" do
                content_type :text
                begin
                    handler.instance.put(request,Submission.new,params[:param])
                rescue Alerter::Exceptions::HandlerError => e
                    error 500, e.to_s
                end
            end
        end

        get '/cron' do
            errors = []
            Alerter::Tags.handlers.each do |tag, handler|
                # An exception raised here causes the whole handler to fail
                begin
                    # Handle received submissions
                    submissions = Submission.all(:tag => tag, :notification_type => :pending, :order => [:submitted_at.asc])
                    handler.instance.pending(submissions,get_url(request),settings.mailer)
                    # Generate a placeholder submission in case something's amiss
                    submissions = Submission.all(:limit => 10, :tag => tag, :order => [:submitted_at.desc])
                    handler.instance.generate_missing(submissions);
                    # Handle missing submissions
                    submissions = Submission.all(:tag => tag, :notification_type => :missing, :order => [:submitted_at.asc])
                    handler.instance.missing(submissions,get_url(request),settings.mailer)
                    # Handle unsent notifications
                    submissions = Submission.all(:tag => tag, :notification_type => :sending, :order => [:submitted_at.asc])
                    handler.instance.unsent(submissions,get_url(request),settings.mailer)
                    # Remove old submissions
                    submissions = Submission.all(:tag => tag, :order => [:submitted_at.desc])
                    handler.instance.remove_old(submissions);
                rescue Alerter::Exceptions::AlerterError => e
                    errors.push "#{tag} #{e.class} #{e.message}"
                    next
                end
            end
            unless errors.empty?
                return 500, "Not OK - #{errors.length} errors - last: #{errors.last}\n"
            end
            return "OK\n"
        end

    end
end
