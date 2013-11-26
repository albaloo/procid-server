class CriteriaStatus
	include DataMapper::Resource
	property :id,           Serial
	property :score,        Integer,   :default => 0
	property :created_at,	DateTime
	belongs_to :criteria
	belongs_to :idea
	belongs_to :participant
	has 1, :comment#, :required => false
end
