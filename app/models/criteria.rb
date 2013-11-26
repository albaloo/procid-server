class Criteria
	include DataMapper::Resource
	property :id,           Serial
	property :currentId, Integer
	property :title,        String
	property :description,        String
	belongs_to :issue,:required=>false
	belongs_to :participant
	has n, :criteria_statuses

	def destroy_criteria
		if not(criteria_statuses.nil?)
			criteria_statuses.comment.destroy			#destroy associated criteria statuses and their
			# comments
			#criteria_statuses.comment
			criteria_statuses.destroy
		end
		return destroy
	end
end
