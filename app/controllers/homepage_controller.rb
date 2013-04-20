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
						:participant => currentParticipant,
						:issue=>currentIssue
						}
			if !(curr["image"].eql?(" "))
				currentComment.has_image=true
			end

			#Since patch tag is determined in the client side it will be applied here
			tags = curr["tags"]
			tags.each do |t|
				tag = Tag.first_or_create({:name => t, :comment => currentComment})		
			end
								
			currentComment.raise_on_save_failure = true
			currentComment.save
		end
		if(numPrevComments < commentInfos.length)
			if(numPrevComments<7)
				numPrevComments=0
			else
				numPrevComments-=7
			end
			currentIssue.find_conversations(numPrevComments,5,2)
			currentIssue.find_ideas(numPrevComments,10,1,3)
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
			curr_json["idea"]="#1"
			curr_json["tone"]="positive"
			curr_json["criteria"]=Array.new
			curr_json["commented_at"]=comments[count].commented_at
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
end
