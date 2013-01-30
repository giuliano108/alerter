module Tags
    class Dhcpclone < Tags::Handler
        def initialize
            super
            case Tags.get_environment
            when :production
                @config = {
                    :recipients => ['it@domain.co.uk'],
                    :from       => 'DHCP VM clone <alerter@monitoring.domain.co.uk>'
                }
            when :development
                @config = {
                    :recipients => ['giuliano@domain.co.uk'],
                    :from       => 'DHCP VM clone <root@alerter>'
                }
            else
                fail 'Unknown environment'
            end
        end

        def pending(submissions,url,mailer)
            submissions.each do |submission|
                submission.notification_type = :sending 
                submission.save or raise Exceptions::SaveFailed.new 'sending'
                subject, body = '', ''
                if submission.content.has_key? 'error'
                    subject = 'ERROR - ' + submission.content['error']
                    body    = "Details here: " + url
                    submission.notification_type = :alert
                else
                    elapsed = ((submission.content['done'] - submission.content['start']) * 1.day / 1.minute).to_i
                    subject = "OK - completed in #{elapsed} minutes"
                    body    = submission.content.to_yaml
                    body.gsub!(%r|^---[\r\n]+|,'')
                    body.gsub!(%r|!ruby/object:DateTime |,'')
                    body    << "\nDetails here: " + url
                    submission.notification_type = :notice
                end
                #puts "S: " + subject
                #puts "B: " + body
                mailer.send(@config[:from],@config[:recipients],subject,body)
                submission.notified_at = DateTime.now
                submission.save or raise Exceptions::SaveFailed.new 'sent'
            end
        end

        def put(request,submission,param)
            dhcp_clone = {}
            error = nil
            request.body.read.each_line do |line|
                begin
                    dhcp_clone['start']    = DateTime.parse($1) if line.match(/^start:\s+([^\r\n]*)/)
                    dhcp_clone['done']      = DateTime.parse($1) if line.match(/^done:\s+([^\r\n]*)/)
                    dhcp_clone['removing'] = $1 if line.match(/^removing:\s+([^\r\n]*)/)
                    dhcp_clone['cloning']  = $1 if line.match(/^cloning:\s+([^\r\n]*)/)
                    error = $1 if line.match(/^error:\s+([^\r\n]*)/)
                rescue ArgumentError => e
                    error ||= e.to_s
                end
            end
            if error.nil? and ["start", "done", "removing", "cloning"].all? {|k| dhcp_clone.has_key? k}
                if dhcp_clone['removing'] == 'dhcp-standalone-clone'
                    dhcp_clone.delete 'removing'
                else
                    error ||= "Corrupted data? (removing)"
                end
                if dhcp_clone['cloning'] == 'in progress'
                    dhcp_clone.delete 'cloning'
                else
                    error ||= "Corrupted data? (cloning)"
                end
                if ((dhcp_clone['done'] - dhcp_clone['start']) * 1.day / 1.minute).to_i < 2
                    error ||= "Negative (or too short) clone time"
                end
            else
              error ||= "Missing data?"
            end
            #p dhcp_clone
            dhcp_clone['error']     = error if !error.nil?
            submission.tag          = 'dhcpclone'
            submission.submitted_at = DateTime.now
            submission.content      = dhcp_clone
            submission.save or raise Exceptions::HandlerError.new, "Can\'t save\n"
            error.nil? or raise Exceptions::HandlerError.new, "#{error}\n"
            return "OK\n"
        end
    end
end
