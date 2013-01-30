module Tags
    class Ccftp < Tags::Handler
        def initialize
            super
            case Tags.get_environment
            when :production
                @config = {
                    :recipients => ['it@domain.co.uk'],
                    :from       => 'CCFTP Backup <alerter@monitoring.domain.co.uk>'
                }
            when :development
                @config = {
                    :recipients => ['giuliano@domain.co.uk'],
                    :from       => 'CCFTP Backup <root@alerter>'
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
                    r = submission.content['runtime']
                    t = submission.content['files']['total']
                    c = submission.content['files']['copied']
                    s = submission.content['files']['skipped']
                    subject = "OK - runtime #{r} - total/copied/skipped: #{t}/#{c}/#{s}"
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
            counters = []
            counters_fields = %w{total copied skipped mismatch failed extras}
            ccftp_backup = {}
            error = nil
            request.body.read.each_line do |line|
                if line.match(/^\s.*Dirs :\s+([^\r\n]*)/)
                    ccftp_backup['dirs'] = Hash[counters_fields.zip($1.split /\s+/)]
                end
                if line.match(/^\s.*Files :\s+([^\r\n]*)/)
                    ccftp_backup['files'] = Hash[counters_fields.zip($1.split /\s+/)]
                end
                ccftp_backup['runtime'] = $1 if line.match(/^\s.*Times :\s+([^\s]*)/)
                begin
                    ccftp_backup['ended'] = DateTime.parse($1) if line.match(/^\s.*Ended :\s+([^\r\n]*)/)
                rescue ArgumentError => e
                    error ||= e.to_s
                end
            end
            error ||= "Missing data?" unless ["dirs", "files", "runtime", "ended"].all? {|k| ccftp_backup.has_key? k}
            #p ccftp_backup
            ccftp_backup['error']   = error if !error.nil?
            submission.tag          = 'ccftp'
            submission.submitted_at = DateTime.now
            submission.content      = ccftp_backup
            submission.save or raise Exceptions::HandlerError.new, "Can\'t save\n"
            error.nil? or raise Exceptions::HandlerError.new, "#{error}\n"
            return "OK\n"
        end
    end
end
