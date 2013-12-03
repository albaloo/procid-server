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
	
	def inviteLensClicked
    issueLink = params[:issueLink]
    userName = params[:userName]
    tagName = params[:tagName]
    if(issueLink.ends_with?('#'))
    issueLink.chop
    end
    currentIssue = Issue.first(:link => issueLink)
    currentParticipant = Participant.first_or_create({:user_name =>userName})

    addAction(currentParticipant,currentIssue,"Invite Tag Clicked",tagName,nil,nil,nil)
    render :json => { }
  end
  
  def invitedParticipant
    issueLink = params[:issueLink]
    userName = params[:userName]
    invitedUserName = params[:invitedUserName]
    if(issueLink.ends_with?('#'))
    issueLink.chop
    end
    currentIssue = Issue.first(:link => issueLink)
    currentParticipant = Participant.first_or_create({:user_name =>userName})

    addAction(currentParticipant,currentIssue,"Invited participant",invitedUserName,nil,nil,nil)
    render :json => { }
  end

  def addAction(participant,issue,name,oldFirst,oldSecond,idFirst,idSecond)
    action = UserAction.first_or_create({
      :participant => participant,
      :issue => issue,
      :actionName => name,
      :oldContentFirst => oldFirst,
      :oldContentSecond => oldSecond,
      :newIDFirst => idFirst,
      :newIDSecond => idSecond,
      :lastModified => Time.now
    })
  end

	protected

	def authenticate
  
  Rails.logger.info "request.env['HTTP_ORIGIN']: #{request.env['HTTP_ORIGIN']}, #{request.headers['HTTP_ORIGIN']}"
      
    allowed_sites = ["http://drupal.org/node/","https://drupal.org/node/","http://www.drupal.org/node/","https://www.drupal.org/node/", "http://drupal.org/comment/","https://drupal.org/comment/","http://www.drupal.org/comment/", "https://www.drupal.org/comment/"]
    return allowed_sites.include?(request.env['HTTP_ORIGIN'])
      
    #authenticate_or_request_with_http_basic do |username, password|
    # username == "procid" && password == "procid"
    #end
  end
end
