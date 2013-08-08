require 'pony'

module Alerter

    class Mailer
        def send(from, to, subject, body)
            Pony.mail(:from => from,
                      :to => to,
                      :via => Alerter[:pony_via],
                      :via_options => Alerter[:pony_options],
                      :subject => subject,
                      :body => body)
        end
    end

end
