module Alerter::Exceptions
    class AlerterError < StandardError; end
    class HandlerError < AlerterError; end
    class SaveFailed < AlerterError; end
    class DestroyFailed < AlerterError; end
end
