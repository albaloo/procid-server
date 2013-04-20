class IdeapageController < ApplicationController

	def setIdeaStatus
                issueLink = params[:issueLink]
		commentTitle = params[:commentTitle]
                ideaStatus = params[:status]

		if(issueLink.ends_with?('#'))
                  issueLink.chop
                end
		currentIssue = Issue.first(:link => issueLink)
		currentCommentIdea = Comment.first({:title => commentTitle, :issue=>currentIssue}).ideasource
		currentCommentIdea.attributes = {
			:status=>ideaStatus
		}
		currentCommentIdea.save

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
		currentIssue = Issue.first(:link => issueLink)
		currentIdea = Comment.first(:title => commentTitle, :issue => currentIssue).ideasource
		currentParticipant = Participant.first_or_create({:user_name =>userName})
		currentCriteria = Criteria.first({:issue => currentIssue, :id => criteriaID})
		currentCriteriaStatus = CriteriaStatus.first_or_create({:criteria=>currentCriteria, :participant=>currentParticipant, :idea => currentIdea},{:created_at=>Time.now, :score => criteriaValue})
		newCommentTitle = currentIssue.getNewCommentTitle()
		newComment = Comment.first_or_create({:issue => currentIssue, :participant => currentParticipant, :title => newCommentTitle}, {:content =>commentContent, :link => issueLink+"#comment-"+newCommentTitle, :criteria_status => currentCriteriaStatus})
		#newComment.updateLink()

		render :json => { }


	end

	def editCriteria
		issueLink = params[:issueLink]
		updatedCriterias = params[:updatedCriterias]
            
		if(issueLink.ends_with?('#'))
                  issueLink.chop
                end
		currentIssue = Issue.first(:link => issueLink)
		updatedCriterias.each do |curr|	
			currentCriteria = Criteria.first({:issue => currentIssue, :id => curr["id"]})
			currentCriteria.update({:title => curr["title"], :description => curr["description"]})
			currentCriteria.save
		end
		render :json => { }		
	end

	def deleteCriteria
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
		render :json => { }		

	end

end
