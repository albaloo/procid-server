class Criteria
  include DataMapper::Resource
  property :id,           Serial
  property :title,        String
  property :description,        String
  belongs_to :issue,:required=>false
  belongs_to :participant
  has n, :criteria_statuses

end
