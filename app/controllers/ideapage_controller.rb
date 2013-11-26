class IdeapageController < ApplicationController

	before_filter :authenticate

	def setIdeaStatus
		issueLink = params[:issueLink]
		userName = params[:userName]
		commentTitle = params[:commentTitle]
		ideaStatus = params[:status]

		if(issueLink.ends_with?('#'))
		issueLink.chop
		end
		currentIssue = Issue.first(:link => issueLink)
		currentCommentIdea = Comment.first({:title => commentTitle, :issue=>currentIssue}).ideasource
		oldStatus=currentCommentIdea.status
		currentCommentIdea.attributes = {
			:status=>ideaStatus
		}
		currentCommentIdea.save

		addAction(Participant.first_or_create(:user_name=>userName),currentIssue,"Set Idea Status",oldStatus,nil,currentCommentIdea.id,nil)

		render :json => { }
	end

	def deleteIdea
		issueLink = params[:issueLink]
		userName = params[:userName]
		commentTitle = params[:commentTitle]

		if(issueLink.ends_with?('#'))
		issueLink.chop
		end
		currentIssue = Issue.first(:link => issueLink)
		currentComment = Comment.first({:title => commentTitle, :issue=>currentIssue})
		currentCommentIdea = currentComment.ideasource
		oldComment=Comment.first({:title => commentTitle, :issue=>currentIssue})
		oldTitle=oldComment.title
		oldContent=oldComment.content
		currentCommentIdea.destroy_idea
		currentComment.updateSummary
		addAction(Participant.first_or_create(:user_name=>userName),currentIssue,"Delete Idea",oldTitle,oldContent,nil,nil)

		result_json=Hash.new
		result_json["summary"]=currentComment.summary
		render :json => result_json.to_json

	end

	def addNewComment
		issueLink = params[:issueLink]
		userName = params[:userName]
		commentTitle = params[:commentTitle]
		newCommentTitle = params[:newCommentTitle]
		newCommentLink = params[:newCommentLink]
		commentContent = params[:content]
		tone = params[:tone]

		if(issueLink.ends_with?('#'))
		issueLink.chop
		end
		currentIssue = Issue.first(:link => issueLink)
		currentIdea = Comment.first(:title => commentTitle, :issue => currentIssue).ideasource
		currentParticipant = Participant.first_or_create({:user_name =>userName})
		time = Time.now
		newComment = Comment.first_or_create({:issue => currentIssue, :participant => currentParticipant, :title => newCommentTitle}, {:content =>commentContent, :link => newCommentLink, :idea => currentIdea, :commented_at=>time, :tone => tone})

		addAction(currentParticipant,currentIssue,"Add New Comment",nil,nil,newComment.id,currentIdea.id)

		result_json=Hash.new
		result_json["commented_at"]=time
		newComment.updateSummary()
		result_json["summary"]=newComment.summary
		render :json => result_json.to_json
	end

	def addCriteria
		issueLink = params[:issueLink]
		userName = params[:userName]
		criteriaTitle = params[:title]
		criteriaDescription = params[:description]
		criteriaID = params[:id]
		newCommentTitle = params[:newCommentTitle]
		newCommentLink = params[:newCommentLink]
		newCommentContent = params[:newCommentContent]

		if(issueLink.ends_with?('#'))
		issueLink.chop
		end
		currentIssue = Issue.first(:link => issueLink)
		currentParticipant = Participant.first_or_create({:user_name
		# =>userName})#,{:link=>issue["authorLink"]})
		currentCriteria = Criteria.first_or_create({:issue => currentIssue, :currentId => criteriaID},{:title=>criteriaTitle, :description=>criteriaDescription, :participant => currentParticipant})
		currentCriteria.save

		time = Time.now
		newComment = Comment.first_or_create({:issue => currentIssue, :participant => currentParticipant, :title => newCommentTitle}, {:content =>newCommentContent, :link => newCommentLink, :commented_at=>time, :tone => "neutral"})

		addAction(currentParticipant,currentIssue,"Add Criteria",nil,nil,currentCriteria.id,nil)

		result_json=Hash.new
		result_json["commented_at"]=time
		newComment.updateSummary()
		result_json["summary"]=newComment.summary
		render :json => result_json.to_json
	end

	def updateCriteriaStatus
		issueLink = params[:issueLink]
		userName = params[:userName]
		criteriaValue = params[:value]
		criteriaID = params[:id]
		commentTitle = params[:commentTitle]
		newCommentTitle = params[:newCommentTitle]
		newCommentLink = params[:newCommentLink]
		commentContent = params[:content]

		if(issueLink.ends_with?('#'))
		issueLink.chop
		end

		tone = "positive"
		if(criteriaValue.to_i < 3)
			tone = "negative"
		elsif(criteriaValue.to_i == 3)
			tone = "neutral"
		end

		currentIssue = Issue.first(:link => issueLink)
		currentIdea = Comment.first(:title => commentTitle, :issue => currentIssue).ideasource
		currentParticipant = Participant.first_or_create({:user_name =>userName})
		currentCriteria = Criteria.first({:issue => currentIssue, :currentId => criteriaID})

		time = Time.now
		currentCriteriaStatus = CriteriaStatus.first_or_create({:criteria=>currentCriteria, :participant=>currentParticipant, :idea => currentIdea})
		oldScore = 0;
		oldContent = "";
		if not(currentCriteriaStatus.comment.nil?)
		oldScore=currentCriteriaStatus.score.to_s
		oldContent=currentCriteriaStatus.comment.content
		currentCriteriaStatus.comment.destroy
		end

		currentCriteriaStatus.attributes = {
			:created_at=>time,
			:score => criteriaValue
		}

		currentCriteriaStatus.raise_on_save_failure = true
		currentCriteriaStatus.save

		newComment = Comment.first_or_create({:issue => currentIssue, :participant => currentParticipant, :title => newCommentTitle});
		newComment.attributes ={:content =>commentContent, :link => newCommentLink, :criteria_status => currentCriteriaStatus, :tone => tone, :commented_at => time}
		newComment.raise_on_save_failure = true
		newComment.save
		#newComment.updateLink()

		currentCriteriaStatus.attributes = {
			:comment=>newComment,
		}
		currentCriteriaStatus.save

		addAction(currentParticipant,currentIssue,"Update Criteria Status",oldScore,oldContent,currentCriteria.id,currentCriteriaStatus.id)

		result_json=Hash.new
		result_json["newCommentTone"]=tone
		result_json["newCommentTime"]=time
		result_json["newCommentSummary"]=newComment.findSummary()
		render :json => result_json.to_json
	end

	def editCriteria
		issueLink = params[:issueLink]
		userName = params[:userName]
		criteriaTitle = params[:title]
		criteriaDescription = params[:description]
		criteriaID = params[:id]

		if(issueLink.ends_with?('#'))
		issueLink.chop
		end
		currentIssue = Issue.first(:link => issueLink)
		currentCriteria = Criteria.first({:issue => currentIssue, :currentId => criteriaID})
		oldTitle=currentCriteria.title
		oldDescription=currentCriteria.description
		currentCriteria.update({:title => criteriaTitle, :description => criteriaDescription})
		currentCriteria.save

		addAction(Participant.first_or_create(:user_name=>userName),currentIssue,"Edit Criteria",oldTitle,oldDescription,currentCriteria.id,nil)

		render :json => { }

	=begin		updatedCriterias.each do |curr|
	currentCriteria = Criteria.first({:issue => currentIssue, :currentId => curr["id"]})
	currentCriteria.update({:title => curr["title"], :description => curr["description"]})
	currentCriteria.save
	end
	render :json => { }
	=end
	end

	def deleteCriteria
		issueLink = params[:issueLink]
		userName = params[:userName]
		criteriaID = params[:id]

		if(issueLink.ends_with?('#'))
		issueLink.chop
		end
		currentIssue = Issue.first(:link => issueLink)
		currentParticipant = Participant.first_or_create({:user_name
		# =>userName})#,{:link=>issue["authorLink"]})
		currentCriteria = Criteria.first({:issue => currentIssue, :currentId => criteriaID})
		oldTitle=currentCriteria.title
		oldDescription=currentCriteria.description
		currentCriteria.destroy_criteria

		addAction(currentParticipant,currentIssue,"Delete Criteria",oldTitle,oldDescription,nil,nil)

		render :json => { }

	end

=begin
Values for addAction call from various actions:
addTag = 				(participant,issue,"Add Tag",nil,nil,new tag ID,nil)
removeTag = 			(participant,issue,"Remove Tag",old tag name,nil,comment ID,nil)
tagClicked = 			(participant,issue,"Tag Clicked",tag name,nil,nil,nil)
setIdeaStatus = 		(participant,issue,"Set Idea Status",old status,nil,current
# comment idea ID,nil)
deleteIdea = 			(participant,issue,"Delete Idea",old comment title, old comment
# content,nil,nil)
addNewComment = 		(participant,issue,"Add New Comment",nil,nil,new comment ID,
# current idea ID)
addCriteria = 			(participant,issue,"Add Criteria",nil,nil, new criteria ID,nil)
updateCriteriaStatus = 	(participant,issue,"Update Criteria Status",old score,
# old content, current criteria ID,current criteria_status ID)
editCriteria = 			(participant,issue,"Edit Criteria",old criteria title,old
# criteria description,current criteria ID,nil)
deleteCriteria = 		(participant,issue,"Delete Criteria",old criteria title,old
# criteria description,nil,nil)
=end
	def addAction(participant,issue,name,oldFirst,oldSecond,idFirst,idSecond)
		Rails.logger.info "part: #{participant}, iss: #{issue}, name: #{name},oldfirst: #{oldFirst},oldSec: #{oldSecond},idFirst: #{idFirst},idSec: #{idSecond}, lasModified: #{Time.now}"
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
