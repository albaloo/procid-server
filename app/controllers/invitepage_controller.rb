class InvitepageController < ApplicationController

	def findPotentialParticipants
                issueLink = params[:issueLink]
                if(issueLink.ends_with?('#'))
                  issueLink.chop
                end
		currentIssue = Issue.first(:link => issueLink)
		prepareOutputFile(currentIssue)
	end
	
	def prepareOutputFile(issue)
		participants_json=issue.find_potential_participants
		final_json=Hash.new
		final_json["invitedMembers"]=participants_json
		tmp_file = "#{Rails.root}/out.txt"
		File.open(tmp_file, 'wb') do |f|
			f.write final_json.to_json
		end
		render :json => final_json.to_json
	end
end
