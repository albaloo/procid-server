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
end
