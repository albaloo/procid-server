class HomepageController < ApplicationController
	skip_before_filter :verify_authenticity_token
	@@data = Rails.root.to_s+'/input.json'


	def postcomments
		#render :nothing => true
		commentInfos = ActiveSupport::JSON.decode(params[:commentInfos])
		issue = ActiveSupport::JSON.decode(params[:issue])
=begin
		tmp_file = "#{Rails.root}/out.txt"
		File.open(tmp_file, 'wb') do |f|
			f.write input[0]["author"]
		end
=end
		issueId = processInputFile(commentInfos,issue)
		prepareOutputFile(issueId)
	end
	
	def processInputFile(commentInfos,issue)
		names=issue["author"].split
		threadInitiator = Participant.first_or_create({:user_name =>issue["author"]},{:link=>issue["authorLink"],:first_name=>names[0],:last_name=>names[1]})
		
		currentIssue = Issue.first_or_create({:link => issue["link"]},{:status =>issue["status"],:participant=>threadInitiator,:title => issue["title"], :created_at=>issue["created_at"]})
		
		#We only need to process the comments that haven't been processed yet.
		numPrevComments = currentIssue.find_num_previous_comments
		index = numPrevComments;
		if(numPrevComments > commentInfos.length)	
			index = commentInfos.length;
		end
		
		commentInfos.from(index).each do |curr|	
			names=curr["author"].split
			currentParticipant = Participant.first_or_create({:user_name =>curr["author"]},{:link=>curr["authorLink"],:first_name=>names[0],:last_name=>names[1]})
			
			currentComment = Comment.first_or_create(:link => curr["link"])
			currentComment.attributes = {
						:title => curr["title"],
						:link => curr["link"],
						:content => curr["content"],
						:commented_at => curr["commented_at"],
						:participant => currentParticipant,
						:issue=>currentIssue
						}
			if !(curr["image"].eql?(" "))
				currentComment.has_image=true
			end

			#average experience + 1 stdev = 349.6124759355
			if!(currentParticipant.experience.nil?)
				if(currentParticipant.experience >= 350)
					Tag.first_or_create({:name => "expert", :comment => currentComment})		
				end
			end

			#Since patch tag is determined in the client side it will be applied here
			tags = curr["tags"]
			tags.each do |t|
				tag = Tag.first_or_create({:name => t, :comment => currentComment})		
				if(t.eql?("patch"))
					currentComment.attributes = {:patch => true}
				end
			end
								
			currentComment.raise_on_save_failure = true
			currentComment.save
		end
		if(numPrevComments==0)
			currentIssue.find_ideas(numPrevComments,10,4,1,3,2,3)#changed the patch and image value to 3
		end
		if(numPrevComments < commentInfos.length)
			if(numPrevComments<7)
				numPrevComments=0
			else
				numPrevComments-=7
			end
			currentIssue.find_conversations(numPrevComments,5,2)
		end
		return currentIssue.id	
	end
	
	def prepareOutputFile(issueId)
		comments_json=Array.new
		issue = Issue.first(:id => issueId)
		comments=Comment.all(:issue => issue)
		count=0
		comments.each do |curr|
			curr_json=Hash.new
			curr_json["title"]=comments[count].title
			curr_json["link"]=comments[count].link
			curr_json["author"]=comments[count].participant.user_name
			curr_json["authorLink"]=comments[count].participant.link
			curr_json["content"]=comments[count].content
			curr_json["tags"]=comments[count].tags.map{|tag| tag.name}
			if comments[count].ideasource.nil?
				curr_json["status"]="Ongoing"
			else
				curr_json["status"]=comments[count].ideasource.status
			end
			curr_json["comments"]=Array.new
			if !(comments[count].ideasource.nil?)
				comments[count].ideasource.getRelatedComments.each do |com|
					curr_json["comments"].push(com.getRelatedCommentInfo)
				end
			end
			curr_json["idea"]="#1"
			curr_json["tone"]=comments[count].tone
			curr_json["criteriaStatuses"]=Array.new
			if !(comments[count].ideasource.nil?)
				comments[count].ideasource.getSortedCriteriaStatuses.each do |stat|
					curr_criterion = Hash.new
					curr_criterion["id"]=stat.criteria.id
					curr_criterion["value"]=stat.score
					curr_criterion["comment"]=stat.comment.content
					curr_criterion["author"]=stat.comment.participant.user_name
					curr_criterion["commentTitle"]=stat.comment.title
					curr_json["criteriaStatuses"].push(curr_criterion)
				end
			end

			curr_json["commented_at"]=comments[count].commented_at
			comments[count].updateSummary()
			curr_json["summary"]=comments[count].summary
		
			comments_json[count]=curr_json
			count=count+1
		end
		criteria=Criteria.all(:issue => issue)
		criteria_json=Array.new
		criteria.each do |curr|
			curr_json=Hash.new
			curr_json["id"]=curr.id
			curr_json["title"]=curr.title
			curr_json["description"]=curr.description
			criteria_json.push curr_json		
		end
		final_json=Hash.new
		final_json["issueComments"]=comments_json
		final_json["criteria"]=criteria_json		
		render :json => final_json.to_json
	end

	def findSentiment
		commentContent = params[:comment]
		info = Comment.findSentiment(commentContent)
		score = 0
		if(info["type"] == "positive" || info["type"] == "negative")
			score=info["score"].to_f
		end

		average = 0
		if(info["type"] == "positive")
			average= 100
		else if(info["type"] == "negative")
			average= 200
		end

		result_json=Hash.new
		result_json["sentimentScore"]=score
		result_json["sentimentTone"]= info["type"]
		result_json["sentimentAverage"]=average
		render :json => result_json.to_json
	end

	def addTag
		issueLink = params[:issueLink]
		userName = params[:userName]
                commentTitle = params[:commentTitle]
		tagName = params[:tag]
		
		if(issueLink.ends_with?('#'))
                  issueLink.chop
                end

		currentIssue = Issue.first(:link => issueLink)
		currentComment = Comment.first(:title => commentTitle, :issue => currentIssue)
		currentParticipant = Participant.first_or_create({:user_name =>userName})

		currentTag = Tag.first_or_create({:comment => currentComment, :name => tagName})
		currentTag.attributes = {:participant => currentParticipant}
		currentTag.save
		
		addAction(currentParticipant,currentIssue,"Add Criteria",nil,nil,currentTag.id,nil)
		
		render :json => { }
	end

	def removeTag
		issueLink = params[:issueLink]
		userName = params[:userName]
                commentTitle = params[:commentTitle]
		tagName = params[:tag]
		
		if(issueLink.ends_with?('#'))
                  issueLink.chop
                end

		currentIssue = Issue.first(:link => issueLink)
		currentComment = Comment.first(:title => commentTitle, :issue => currentIssue)
		currentParticipant = Participant.first_or_create({:user_name =>userName})

		currentTag = Tag.first({:comment => currentComment, :name => tagName})#, {:participant => currentParticipant})
		oldName=currentTag.name
		currentTag.destroy
		
		addAction(currentParticipant,currentIssue,"Remove Tag",oldName,nil,currentComment.id,nil)
		
		render :json => { }
	end
	
	def tagClicked
		issueLink = params[:issueLink]
		userName = params[:userName]
		tagName = params[:tagName]
		if(issueLink.ends_with?('#'))
                  issueLink.chop
        end
		currentIssue = Issue.first(:link => issueLink)
		currentParticipant = Participant.first_or_create({:user_name =>userName})
		
		addAction(currentParticipant,currentIssue,"Tag Clicked",tagName,nil,nil,nil)
		
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
end
