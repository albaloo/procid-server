require 'iconv'

class HomepageController < ApplicationController
	skip_before_filter :verify_authenticity_token
	@@data = Rails.root.to_s+'/input.json'
	before_filter :authenticate

	def postcomments
		commentInfos = ActiveSupport::JSON.decode(params[:commentInfos])
		issue = ActiveSupport::JSON.decode(params[:issue])

		issueId = processInputFile(commentInfos,issue)
		prepareOutputFile(issueId)
	end

  def issueExists
    issueLink = params[:issueLink]
    result = 0
    if Issue.count(:link=>issueLink) > 0
      result = Issue.first(:link=>issueLink).find_num_previous_comments
    end
   
    result_json = Hash.new
    result_json["result"]=result
    render :json => result_json.to_json
  end
  
  def startProcid
    issueLink = params[:issueLink]
    userName = params[:userName]

    if(issueLink.ends_with?('#'))
    issueLink.chop
    end

    currentIssue = Issue.first(:link => issueLink)
    currentParticipant = Participant.first_or_create({:user_name =>userName})

    addAction(currentParticipant,currentIssue,"Start Procid",nil,nil,nil,nil)

    render :json => { }
  end
  
	def processInputFile(commentInfos,issue)
		ideaComments = Rails.cache.read("ideaComments")
		ideaReferences = Rails.cache.read("ideaReferences")
		names=issue["author"].split
		participantName = Iconv.iconv('ascii//translit', 'utf-8', issue["author"])[0]
		threadInitiator = Participant.first_or_create({:user_name =>participantName},{:link=>issue["authorLink"],:first_name=>names[0],:last_name=>names[1]})

		currentIssue = Issue.first_or_create({:link => issue["link"]},{:status =>issue["status"],:participant=>threadInitiator,:title => issue["title"], :created_at=>issue["created_at"]})

		#We only need to process the comments that haven't been processed yet.
		numPrevComments = currentIssue.find_num_previous_comments
		index = numPrevComments;
		if(numPrevComments > commentInfos.length)
		index = commentInfos.length;
		end

		commentInfos.from(index).each do |curr|
			names=curr["author"].split
			currentparticipantName = Iconv.iconv('ascii//translit', 'utf-8', curr["author"])[0]
			currentParticipant = Participant.first_or_create({:user_name =>currentparticipantName},{:link=>curr["authorLink"],:first_name=>names[0],:last_name=>names[1]})

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

			#If a new idea has been added through the comment composition window
			index = 0
			while (!(ideaComments.nil?) && index < ideaComments.size)
				if ideaComments[index][:authorLink] == currentParticipant.link and ideaComments[index][:content] == currentComment.content and ideaComments[index][:issueLink] == currentIssue.link
					statusStr = "Ongoing"

					if currentComment.patch
						statusStr = "Implemented"
					end

					idea = Idea.first_or_create({:comment=> currentComment},{:status=>statusStr})
					currentComment.ideasource = idea
					tag = Tag.first_or_create({:name => "idea", :comment => currentComment, :participant => currentParticipant})
				currentComment.save
				ideaComments.delete_at(index)
				else
				index+=1
				end
			end

			index = 0
			while (!(ideaReferences.nil?) && index < ideaReferences.size)
				if ideaReferences[index][:authorLink] == currentParticipant.link and ideaReferences[index][:content] == currentComment.content and ideaReferences[index][:issueLink] == currentIssue.link
					comments = Comment.all(:issue => currentIssue)
					ideaCom = comments[Integer(ideaReferences[index][:ideaNum]) - 1]
					statusStr = "Ongoing"

					if ideaCom.patch
						statusStr = "Implemented"
					end

					idea = Idea.first_or_create({:comment=> ideaCom},{:status=>statusStr})
					ideaCom.ideasource = idea
					tag = Tag.first_or_create({:name => "idea", :comment => ideaCom, :participant => ideaCom.participant})
					currentComment.attributes = {:idea => idea, :tone => ideaReferences[index][:type]}
				ideaCom.summary = ideaCom.findSummary
				currentComment.save
				idea.save
				ideaCom.save
				ideaReferences.delete_at(index)
				else
				index+=1
				end
			end

			currentComment.raise_on_save_failure = true
			currentComment.save
		end
		
		if(numPrevComments==0)
		currentIssue.find_ideas(numPrevComments,10,4,1,3,2,3,2,1)#changed the patch and
		# image value to 3
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

	def newIdeaComment
		ideaComments = Rails.cache.read("ideaComments")
		if ideaComments.nil?
			ideaComments = Array.new
		end

		info = Hash.new
		info[:authorLink] = params[:authorLink]
		info[:content] = params[:content]
		issueLink = params[:issueLink]
		if(issueLink.ends_with?('#'))
		issueLink.chop
		end

    currentIssue = Issue.first(:link => issueLink)
    currentParticipant = Participant.first_or_create({:link =>info[:authorLink]})
    addAction(currentParticipant,currentIssue,"Mark Comment as Idea",info[:content],nil,nil,nil)

		info[:issueLink] = issueLink
		ideaComments.push(info)
		Rails.cache.write("ideaComments", ideaComments)
		render :nothing => true
	end

	def newIdeaReference
		ideaReferences = Rails.cache.read("ideaReferences")
		if ideaReferences.nil?
			ideaReferences = Array.new
		end
		info = Hash.new
		info[:authorLink] = params[:authorLink]
		info[:content] = params[:content]
		issueLink = params[:issueLink]

		if(issueLink.ends_with?('#'))
		issueLink.chop
		end

    currentIssue = Issue.first(:link => issueLink)
    currentParticipant = Participant.first_or_create({:link =>info[:authorLink]})
    addAction(currentParticipant,currentIssue,"Mark Comment as referal to Idea",info[:content],info[:ideaNum],nil,nil)

		info[:issueLink] = issueLink
		info[:ideaNum] = params[:ideaNum]
		info[:type] = params[:type]
		ideaReferences.push(info)
		Rails.cache.write("ideaReferences", ideaReferences)
		render :nothing => true
	end

	def changeCommentTone
	  issueLink = params[:issueLink]
    userName = params[:userName]
		comment = Comment.first(:link => params[:commentLink])
		
		if(issueLink.ends_with?('#'))
		 issueLink.chop
    end

    currentIssue = Issue.first(:link => issueLink)
    currentParticipant = Participant.first_or_create({:user_name =>userName})
		comment.update(:tone => params[:tone])

		addAction(currentParticipant,currentIssue,"Change Comment Tone",comment.tone,nil,comment.id,nil)
  
		render :nothing => true
	end

	def prepareOutputFile(issueId)
		final_json=Hash.new
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
			curr_json["author"]=currCriteria.participant.user_name
			criteria_json.push curr_json
		end

		final_json["issueComments"]=comments_json
		final_json["criteria"]=criteria_json

		render :json => final_json.to_json
	end

	def time_diff_milli(start, finish)
		(finish - start) * 1000.0
	end

	def findNegativeWords
		commentContent = params[:comment]
		issueLink = params[:issueLink]
    userName = params[:userName]
    
    if(issueLink.ends_with?('#'))
    issueLink.chop
    end

    currentIssue = Issue.first(:link => issueLink)
    currentParticipant = Participant.first_or_create({:user_name =>userName})
    
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
		message="We did not detect any negative words in your comment. You are good to go!"
		positiveRatio = 0.0
		negativeRatio = 0.0

		if(totalNumWords-numStopWords == 0 || totalNumWords == 0)
			message = "Please enter a valid comment."
		highlightedWords = []
		else
		positiveRatio = numPositiveWords.to_f/(totalNumWords-numStopWords)
		negativeRatio = numNegativeWords.to_f/(totalNumWords-numStopWords)
		end

		#top 1% positive: 0.54, top negative: 0.11
		#if(positiveRatio > 0.05)
		#	message = "Nice, your comment is more positive than average comments in
		# Drupal!"
		#	highlightedWords = []
		#end
		if(negativeRatio > 0)#if(negativeRatio > 0.01)
			message = "To reach consensus, it is important to have a constructive tone. Highlighted words are negative, please consider rephrasing in a more constructive manner."
		#message = "Your comment is more negative than the average comments in Drupal. Please consider revising it."
		end
		
		addAction(currentParticipant,currentIssue,"Find Negative Words",commentContent,message,nil,nil)
		
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

		currentTag = Tag.first({:comment => currentComment, :name => tagName})#,
		# {:participant => currentParticipant})
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

  def sendFeedback
    issueLink = params[:issueLink]
    userName = params[:userName]
    if(issueLink.ends_with?('#'))
      issueLink.chop
    end
    
    currentIssue = Issue.first(:link => issueLink)
    currentParticipant = Participant.first_or_create({:user_name =>userName})

    addAction(currentParticipant,currentIssue,"Procid Feedback",params[:content],nil,nil,nil)
    render :json => { }
  end

=begin
Values for addAction call from various actions:
addNewIdea =  (participant,issue,"Add New Idea",nil,nil,new idea ID,current
# comment ID)
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

