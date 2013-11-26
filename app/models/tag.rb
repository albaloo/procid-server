class Tag
	include DataMapper::Resource
	property :id,           Serial
	property :name,        String,   :required => true

	belongs_to :comment
	belongs_to :participant

end

