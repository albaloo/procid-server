class Network
	include DataMapper::Resource
	property :id,           Serial
	property :commented_at,	DateTime

	belongs_to :participant
	belongs_to :issue

end
