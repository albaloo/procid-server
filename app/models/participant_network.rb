class ParticipantNetwork
  include DataMapper::Resource
  property :id,           Serial
  property :commented_at,	DateTime

  belongs_to :source, 'Participant', :key => true
  belongs_to :target, 'Participant', :key => true
 
end
