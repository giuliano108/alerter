class Submission
  include DataMapper::Resource  
  property :id, Serial
  property :tag, String
  property :content, Object
  property :submitted_at, DateTime, :index => true
  property :notification_type, Enum[:pending,:sending,:alert,:notice,:missing], :default => :pending
  property :notified_at, DateTime, :required => false
  # :pending       : just saved submission, still to be dealt with.
  # :sending       : alert/notice about to be sent. This state should be immediately followed by :alert/:notice.
  # :alert/:notice : alert/notice sent, nothing else to do.
  # :missing       : no submission has been received during the last schedule interval
end

DataMapper.auto_upgrade!
