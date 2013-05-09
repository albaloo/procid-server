class IdeapageController < ApplicationController

#	before_filter :authenticate

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
		currentCommentIdea = Comment.first({:title => commentTitle, :issue=>currentIssue}).ideasource
		oldComment=Comment.first({:title => commentTitle, :issue=>currentIssue})
		oldTitle=oldComment.title
		oldContent=oldComment.content
		currentCommentIdea.destroy_idea
		
		addAction(Participant.first_or_create(:user_name=>userName),currentIssue,"Delete Idea",oldTitle,oldContent,nil,nil)

		render :json => { }
	end

        def addNewComment
		issueLink = params[:issueLink]
		userName = params[:userName]
                commentTitle = params[:commentTitle]
		commentContent = params[:content]
		tone = params[:tone]
		
		if(issueLink.ends_with?('#'))
                  issueLink.chop
                end
		currentIssue = Issue.first(:link => issueLink)
		currentIdea = Comment.first(:title => commentTitle, :issue => currentIssue).ideasource
		currentParticipant = Participant.first_or_create({:user_name =>userName})
		newCommentTitle = currentIssue.getNewCommentTitle()
		newComment = Comment.first_or_create({:issue => currentIssue, :participant => currentParticipant, :title => newCommentTitle}, {:content =>commentContent, :link => issueLink+"#comment-"+newCommentTitle, :idea => currentIdea, :commented_at=>Time.now, :tone => tone})
		
		addAction(currentParticipant,currentIssue,"Add New Comment",nil,nil,newComment.id,currentIdea.id)

		render :json => { }
	end

        def addCriteria
		issueLink = params[:issueLink]
		userName = params[:userName]
		criteriaTitle = params[:title]
                criteriaDescription = params[:description]
                criteriaID = params[:id]
		
		if(issueLink.ends_with?('#'))
                  issueLink.chop
                end
		currentIssue = Issue.first(:link => issueLink)
		currentParticipant = Participant.first_or_create({:user_name =>userName})#,{:link=>issue["authorLink"]})
		currentCriteria = Criteria.first_or_create({:issue => currentIssue, :id => criteriaID},{:title=>criteriaTitle, :description=>criteriaDescription, :participant => currentParticipant})
		currentCriteria.save
		
		addAction(currentParticipant,currentIssue,"Add Criteria",nil,nil,currentCriteria.id,nil)
		
		render :json => { }		
	end

	def updateCriteriaStatus
		issueLink = params[:issueLink]
		userName = params[:userName]
                criteriaValue = params[:value]
                criteriaID = params[:id]
                commentTitle = params[:commentTitle]
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
		currentCriteria = Criteria.first({:issue => currentIssue, :id => criteriaID})
		currentCriteriaStatus = CriteriaStatus.first_or_create({:criteria=>currentCriteria, :participant=>currentParticipant, :idea => currentIdea})
		oldComment=Comment.first({:title => commentTitle, :issue=>currentIssue})
		oldScore=currentCriteriaStatus.score.to_s
		oldContent=oldComment.content

		currentCriteriaStatus.attributes = {
			:created_at=>Time.now, 
			:score => criteriaValue
		}
		currentCriteriaStatus.save
		newCommentTitle = currentIssue.getNewCommentTitle()
		newComment = Comment.first_or_create({:issue => currentIssue, :participant => currentParticipant, :title => newCommentTitle}, {:content =>commentContent, :link => issueLink+"#comment-"+newCommentTitle, :criteria_status => currentCriteriaStatus, :tone => tone, :commented_at => Time.now})
		#newComment.updateLink()

		currentCriteriaStatus.attributes = {
			:comment=>newComment, 
		}
		currentCriteriaStatus.save

		
		addAction(currentParticipant,currentIssue,"Update Criteria Status",oldScore,oldContent,currentCriteria.id,currentCriteriaStatus.id)

		result_json=Hash.new
		result_json["newCommentTitle"]=newCommentTitle
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
		currentCriteria = Criteria.first({:issue => currentIssue, :id => criteriaID})
		oldTitle=currentCriteria.title
		oldDescription=currentCriteria.description
		currentCriteria.update({:title => criteriaTitle, :description => criteriaDescription})
		currentCriteria.save
		
		addAction(Participant.first_or_create(:user_name=>userName),currentIssue,"Edit Criteria",oldTitle,oldDescription,currentCriteria.id,nil)
		
 		render :json => { }		

=begin		updatedCriterias.each do |curr|	
			currentCriteria = Criteria.first({:issue => currentIssue, :id => curr["id"]})
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
		currentParticipant = Participant.first_or_create({:user_name =>userName})#,{:link=>issue["authorLink"]})
		currentCriteria = Criteria.first({:issue => currentIssue, :id => criteriaID})
		oldTitle=currentCriteria.title
		oldDescription=currentCriteria.description
		currentCriteria.destroy
		
		addAction(currentParticipant,currentIssue,"Delete Criteria",oldTitle,oldDescription,nil,nil)
		
		render :json => { }		

	end
	
	
	
	
=begin
	Values for addAction call from various actions:
	addTag = 				(participant,issue,"Add Tag",nil,nil,new tag ID,nil)
	removeTag = 			(participant,issue,"Remove Tag",old tag name,nil,comment ID,nil)
	tagClicked = 			(participant,issue,"Tag Clicked",tag name,nil,nil,nil)
	setIdeaStatus = 		(participant,issue,"Set Idea Status",old status,nil,current comment idea ID,nil)
	deleteIdea = 			(participant,issue,"Delete Idea",old comment title, old comment content,nil,nil)
	addNewComment = 		(participant,issue,"Add New Comment",nil,nil,new comment ID, current idea ID)
	addCriteria = 			(participant,issue,"Add Criteria",nil,nil, new criteria ID,nil)
	updateCriteriaStatus = 	(participant,issue,"Update Criteria Status",old score, old content, current criteria ID,current criteria_status ID)
	editCriteria = 			(participant,issue,"Edit Criteria",old criteria title,old criteria description,current criteria ID,nil)
	deleteCriteria = 		(participant,issue,"Delete Criteria",old criteria title,old criteria description,nil,nil)
=end
	def addAction(participant,issue,name,oldFirst,oldSecond,idFirst,idSecond)
		Rails.logger.info "part: #{participant}, iss: #{issue}, name: #{name},oldfirst: #{oldFirst},oldSec: #{oldSecond},idFirst: #{idFirst},idSec: #{idSecond}"
		action = UserAction.first_or_create({
									:participant => participant,
									:issue => issue,
									:actionName => name, 
									:oldContentFirst => oldFirst,
									:oldContentSecond => oldSecond,
									:newIDFirst => idFirst,
									:newIDSecond => idSecond
								})
	end

	protected

	def authenticate
 		authenticate_or_request_with_http_basic do |username, password|
			username == "procid" && password == "procid"
		end
	end

end
