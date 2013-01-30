require File.join(File.dirname(__FILE__), 'environment')

def get_url(request)
    "#{request.scheme}://#{request.host}:#{request.port}"
end

error do
    e = request.env['sinatra.error']
    Kernel.puts e.backtrace.join("\n")
    'Application error'
end

# root page
get '/' do
    @submissions = Submission.all(:order => [:submitted_at.desc])
    haml :root
end

Tags.set_environment Sinatra::Base.environment

Tags.handlers.each do |tag, handler|
    # Usage:
    # tail whatever.log | curl -s -X PUT http://1.1.1.1:9292/tag/whatever --data-binary @-
    put "/#{tag.to_s}/:param" do
        content_type :text
        begin
            handler.instance.put(request,Submission.new,params[:param])
        rescue Exceptions::HandlerError => e
            error 500, e.to_s
        end
    end
end

get '/cron' do
    errors = []
    Tags.handlers.each do |tag, handler|
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
        rescue Exceptions::AlerterError => e
            errors.push "#{tag} #{e.class} #{e.message}"
            next
        end
    end
    unless errors.empty?
        return 500, "Not OK - #{errors.length} errors - last: #{errors.last}\n"
    end
    return "OK\n"
end
