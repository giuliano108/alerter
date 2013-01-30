module Tags
    require 'singleton'
    require 'ice_cube'

    class IceCube::Schedule
        def previous_schedule_range
            # schedule start must be chosen reasonably!
            (range_start, range_end) = occurrences(Time.now)[-2..-1]
            range_start..range_end
        end
    end

    @handlers    = {} # tag => class (singleton)
    @environment = :development

    def self.handlers
        @handlers
    end

    def self.set_environment(env)
        fail "Unknown environment #{env.to_s}" unless env == :development || env == :production
        @environment = env
    end

    def self.get_environment
        @environment
    end

    class Handler
        include Singleton

        def initialize
            @schedule = IceCube::Schedule.new(1.month.ago.beginning_of_day)
            @schedule.add_recurrence_rule IceCube::Rule.daily
            # For example, add these if your schedule doesn't occur on weekends
            #@schedule.add_exception_rule  IceCube::Rule.weekly.day(:saturday)
            #@schedule.add_exception_rule  IceCube::Rule.weekly.day(:sunday)
        end

        def put(request,submission,param); fail "Method not implemented"; end

        def pending(submissions,url,mailer); fail "Method not implemented"; end

        def remove_old(submissions) # assumes descending order
            old = submissions.to_a[60..-1] # by default, keep 60 submissions
            unless old.nil?
                old.each { |s| s.destroy or raise Exceptions::DestroyFailed.new 'remove_old_submission' }
            end
        end

        def generate_missing(submissions)
            return if submissions.empty?
            if submissions.find {|s| on_schedule?(s)}.nil?
                missed_submission                   = submissions.first.class.new
                missed_submission.submitted_at      = @schedule.previous_schedule_range.first
                missed_submission.tag               = self.class.name.gsub(/^.*::/,'').downcase
                missed_submission.notification_type = :missing
                missed_submission.content           = {'error' => 'missed schedule?'}
                missed_submission.save or raise Exceptions::SaveFailed.new 'generate_missing'
            end
        end

        def missing(submissions,url,mailer)
            submissions.each do |submission|
                submission.notification_type = :sending 
                submission.save or raise Exceptions::SaveFailed.new 'sending'
                if submission.content.has_key? 'error'
                    subject =  'ERROR - ' + submission.content['error']
                else
                    subject =  'ERROR - missed schedule?'
                end
                body    =  "No submission has been received during the last schedule interval:\n"
                body    << "a job might have failed to run.\n"
                body    << "Details here: " + url + "\n"
                mailer.send(@config[:from],@config[:recipients],subject,body)
                submission.notified_at = DateTime.now
                submission.notification_type = :alert
                submission.save or raise Exceptions::SaveFailed.new 'sent'
            end
        end

        def unsent(submissions,url,mailer)
            submissions.each do |submission|
                if submission.content.has_key? 'error'
                    subject =  'ERROR - ' + submission.content['error']
                else
                    subject =  'WARNING - email sending failure(s)'
                    submission.content = submission.content.merge({'error' => 'email sending failure'})
                end
                body    =  "I had troubles sending this email out...\n"
                body    << submission.content.to_yaml
                body    << "\nDetails here: " + url
                mailer.send(@config[:from],@config[:recipients],subject,body)
                submission.notified_at = DateTime.now
                submission.notification_type = :alert
                submission.save or raise Exceptions::SaveFailed.new 'unsent'
            end
        end

        def on_schedule?(submission)
            @schedule.previous_schedule_range.cover? submission.submitted_at
        end
    end

    # load handlers
    Dir.glob(File.join(File.dirname(__FILE__),'handlers','*.rb')) do |dir| 
        require File.join(File.dirname(__FILE__),'handlers',File.basename(dir, '.*'))
    end 

    @handlers = self.constants.each_with_object({}) {|c,h| h[c.to_s.downcase.to_sym]=self.const_get(c) unless self.const_get(c) == Tags::Handler}
end
