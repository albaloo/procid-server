class Participant
  include DataMapper::Resource
  property :id,           Serial
  property :user_name,    String,:length=>500,   :required => true
  property :link,    	  String,:length=>500,   :required => false
  property :last_name,    String,   :required => false
  property :first_name,   String,   :required => false
  property :experience,   Integer,   :required => false
  property :usabilityPatches,   Integer,   :required => false
  property :usabilityComments,   Integer,   :required => false
  
  has n, :comments
  has n, :criterias, :required =>false
  has n, :issues,:required =>false
  has n, :user_actions, :required =>false

  has n, :participant_networks, :child_key => [ :source_id ]
  has n, :pnetworks, self, :through => :participant_networks, :via => :target
end
