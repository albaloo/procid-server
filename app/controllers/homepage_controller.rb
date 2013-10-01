class HomepageController < ApplicationController
	skip_before_filter :verify_authenticity_token
	@@data = Rails.root.to_s+'/input.json'
	before_filter :authenticate

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
		#issueId = 
		processInputFile(commentInfos,issue)
		#prepareOutputFile(issueId)
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

			#insert network objects
			currentNet = Network.first_or_create({:participant => currentParticipant, :issue => currentIssue})
			currentNet.attributes = {
					:commented_at => curr["commented_at"]
      			}
      			currentNet.save			

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
			if (not(currentParticipant.experience.nil?) && currentParticipant.experience >= 350)
					t=Tag.first_or_create({:name => "expert", :comment => currentComment, :participant => currentParticipant})		
			end

			#Since patch tag is determined in the client side it will be applied here
			tags = curr["tags"]
			tags.each do |t|
				tag = Tag.first_or_create({:name => t, :comment => currentComment, :participant => currentParticipant})		
				if(t.eql?("patch"))
					currentComment.attributes = {:patch => true}
				end
			end
								
			currentComment.raise_on_save_failure = true
			currentComment.save
		end
		if(numPrevComments == commentInfos.length)
			cashed = true
		else
			cashed = false
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
		prepareOutputFile(currentIssue.id, cashed)
		#return currentIssue.id	
	end
	
	def prepareOutputFile(issueId, cashed)
		final_json=Hash.new
		if cashed
			final_json = JSON.parse( IO.read("results.json"));
		else
		comments_json=Array.new
		issue = Issue.first(:id => issueId)
		comments=Comment.all(:issue => issue)
		count=0
		comments.each do |curr|
			curr_json=Hash.new
			#Setting up idea image for one particular comment
			if(issue.link == "/node/1337554" && comments[count].title == "#1")
				curr_json["image"] = "http://drupal.org/files/Drupal8Wordmark_0.png"
			else
				curr_json["image"] = ""
			end
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
					curr_criterion["id"]=stat.criteria.currentId
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
		criteria.each do |currCriteria|
			curr_json=Hash.new
			curr_json["id"]=currCriteria.currentId
			curr_json["title"]=currCriteria.title
			curr_json["description"]=currCriteria.description
			criteria_json.push curr_json		
		end
		
		final_json["issueComments"]=comments_json
		final_json["criteria"]=criteria_json		
		
		File.open("results.json","w") do |f|
 			f.write(final_json.to_json)
		end

		end
		render :json => final_json.to_json
	end

	def findNegativeWords
		commentContent = params[:comment]
		words=Array.new
		words_file = "#{Rails.root}/words.json"
		currentWords = ""
		File.open(words_file, "r" ) do |f|
			currentWords = JSON.load(f)
		end
		highlightedWords = Array.new
		tokenizer = TactfulTokenizer::Model.new
		sentences = tokenizer.tokenize_text(commentContent)
		totalNumWords = 0
		numStopWords = 0
		numNegativeWords = 0
		numPositiveWords = 0
		sentences.each do |sentence|
			currentSentence = sentence.downcase
			currentWords["negative"].each do |negativeWord|
				if(negativeWord.include?(" ") && currentSentence.include?(negativeWord))
					numNegativeWords = numNegativeWords + 1
					totalNumWords = totalNumWords+1 
					highlightedWords.push(negativeWord);
					currentSentence = currentSentence.sub(negativeWord,"")
					next		
				end
			end

			currentWords["positive"].each do |positiveWord|
				if(positiveWord.include?(" ") && currentSentence.include?(positiveWord))
					numPositiveWords = numPositiveWords + 1
					totalNumWords = totalNumWords+1 
					currentSentence = currentSentence.sub(positiveWord,"")
					next		
				end
			end

			words = currentSentence.split(/\W+/)
			words.each do |word|
				totalNumWords = totalNumWords+1 
				if (currentWords["stopwords"].include? (word))	
					numStopWords = numStopWords+1 
				elsif (currentWords["positive"].include? (word))
					numPositiveWords = numPositiveWords+1 
				elsif (currentWords["negative"].include? (word))
					numNegativeWords = numNegativeWords+1 
					highlightedWords.push(word)
				else
					Rails.logger.info "word: #{word}"
				end

			end
		end
		message="You are good to go!"
		positiveRatio = 0.0
		negativeRatio = 0.0

		if(totalNumWords-numStopWords == 0 || totalNumWords == 0)
			message = "Please enter a valid comment."
			highlightedWords = []
		else
			positiveRatio = numPositiveWords.to_f/(totalNumWords-numStopWords)
			negativeRatio = numNegativeWords.to_f/(totalNumWords-numStopWords)
		end

		Rails.logger.info "numNegative: #{numNegativeWords}"
		Rails.logger.info "numPositive: #{numPositiveWords}"
		Rails.logger.info "numStop: #{numStopWords}"
		Rails.logger.info "total: #{totalNumWords}"
		highlightedWords.each do |word|
			Rails.logger.info "highlighted: #{word}"
		end

#top 1% positive: 0.54, top negative: 0.11
		#if(positiveRatio > 0.05)
		#	message = "Nice, your comment is more positive than average comments in Drupal!"
		#	highlightedWords = []
		#end
		#if(negativeRatio > 0.01)
			message = "To reach consensus, it is important to have a constructive tone. Highlighted words are negative, please consider rephrasing in a more constructive manner."
			#message = "Your comment is more negative than the average comments in Drupal. Please consider revising it."
		#end 
		result_json=Hash.new
		result_json["highlightedWords"]=highlightedWords
		result_json["totalNumWords"]=totalNumWords
		result_json["userMessage"]=message
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

		currentTag = Tag.first_or_create({:comment => currentComment, :name => tagName, :participant => currentParticipant})
		#currentTag.attributes = {:participant => currentParticipant}
		#currentTag.save
		
		addAction(currentParticipant,currentIssue,"Add Tag",nil,nil,currentTag.id,nil)
		
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

	def addNewIdea
	 	issueLink = params[:issueLink]
		userName = params[:userName]
		commentTitle = params[:commentTitle]

		if(issueLink.ends_with?('#'))
                  issueLink.chop
                end
	
		currentIssue = Issue.first(:link => issueLink)
		currentComment = Comment.first({:title => commentTitle, :issue=>currentIssue})
		statusStr = "Ongoing"
		if(currentComment.patch)
			statusStr = "Implemented"
		end
	        idea = Idea.first_or_create({:comment=> currentComment},{:status=>statusStr})    
	        currentComment.ideasource = idea
		currentComment.summary = nil
		currentComment.save

		currentComment.updateSummary
		
		addAction(Participant.first_or_create(:user_name=>userName),currentIssue,"Add New Idea",nil,nil,idea.id,currentComment.id)

		result_json=Hash.new
		result_json["summary"]=currentComment.summary
		render :json => result_json.to_json

	end
	
	def lensClicked
		issueLink = params[:issueLink]
		userName = params[:userName]
		tagName = params[:tagName]
		if(issueLink.ends_with?('#'))
                  issueLink.chop
        	end
		currentIssue = Issue.first(:link => issueLink)
		currentParticipant = Participant.first_or_create({:user_name =>userName})
		
		addAction(currentParticipant,currentIssue,"Tag Clicked",tagName,nil,nil,nil)
		render :json => { }
	end
	

=begin
	Values for addAction call from various actions:
	addNewIdea =  (participant,issue,"Add New Idea",nil,nil,new idea ID,current comment ID)
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


protected

	def authenticate
		#if(request.referer.start_with?("http://drupal.org/node/","https://drupal.org/node/","http://www.drupal.org/node/","https://www.drupal.org/node/"))
		#	return true
		#else
		#	Rails.logger.info "request.referer: #{request.referer}"
		#	head :ok
		#end
 		#authenticate_or_request_with_http_basic do |username, password|
		#	username == "procid" && password == "procid"
		#end
	end
end



=begin
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
=end

