class InvitepageController < ApplicationController

	before_filter :authenticate

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

	protected

	def authenticate
		#	if(request.referer.start_with?("http://drupal.org/node/","https://drupal.org/node/","http://www.drupal.org/node/","https://www.drupal.org/node/"))
		#		return true
		#	else
		#		Rails.logger.info "request.referer: #{request.referer}"
		#		head :ok
		#	end
		#authenticate_or_request_with_http_basic do |username, password|
		#	username == "procid" && password == "procid"
		#end
	end
end
