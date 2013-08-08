module Alerter::Tags
    class Ccftp < Alerter::BaseTags::Robocopy
        def initialize
            @from_name = 'CCFTP Backup'
            super
        end
    end
end
