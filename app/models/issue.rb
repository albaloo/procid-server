class Issue
	include DataMapper::Resource
	include ActionView::Helpers::DateHelper
	property :id,           Serial
	property :title,       String,:length=>1000
	property :status,	String
	property :link,	String,:length=>500,   :required => true
	property :created_at,	DateTime, :required => false

	belongs_to :participant
	has n, :comments, :required => false
	has n, :criterias, :required => false
	has n, :user_actions, :required =>false

	def find_num_previous_comments
		return Comment.count(:issue_id=>id)
	end

	def getNewCommentTitle
		result = Array.new
		result.concat(Comment.all({:issue_id => id}))
		result = result.sort {|x,y| x.commented_at <=> y.commented_at}
		lastCommentTitle = result.last.title[1..-1]
		num = lastCommentTitle.to_i
		lastCommentTitleNumber = num + 1
		Rails.logger.info "lastCommentTitleNumber: #{lastCommentTitleNumber}, result.last.title: #{result.last.title}, lastCommentTitle: #{lastCommentTitle}, num: #{num}"
		return "#"+lastCommentTitleNumber.to_s
	end
	
	#Use helper methods to find potential participants
	def insert_current_participant_issue_relations
		issue = Issue.first({:id => id})
		comments = Comment.all({:issue_id => id})
		comments.each do |comment|
			currentParticipant = Participant.first(:id=>comment.participant.id);
			currentNet = Network.first_or_create({:participant => currentParticipant, :issue => issue})
			currentNet.attributes = {
				:commented_at => comment.commented_at
			}
			currentNet.save
		end
	end

	def find_potential_participants
		if(Network.first(:issue_id=>id).nil?)
			insert_current_participant_issue_relations
		end

		potentials = Array.new
		potentials.concat(find_experienced_potential_participants)
		potentials.concat(find_patchsubmitter_potential_participants)
		potentials.concat(find_consensus_potential_participants)
		potentials.concat(find_recent_potential_participants)
		potentials.concat(find_triad_potential_participants)

		potentials = potentials.uniq
		potentials = potentials.select { |h| !(h['author'].include? "System Message") }
		return potentials
	end

	#select all participants who are not participating in this thread
	def find_all_potential_participants
		adapter = DataMapper.repository(:default).adapter
		issueid = Issue.first(:link => link).id
		command = "SELECT id FROM participants WHERE NOT EXISTS (SELECT participant_id, issue_id FROM networks WHERE networks.participant_id=participants.id AND networks.issue_id=#{issueid});"
		potentials = adapter.select(command)
		return potentials
	end

	def gather_participant_info_description (currentParticipant, num, recency, triads)
		description = ""
		experienceInfo = 0
		#Experience
		if(currentParticipant.experience.nil?)
			description.concat("no experience info")
		experienceInfo = 1
		else
			year = currentParticipant.experience/52
			yearString="years"
			week = currentParticipant.experience%52
			weekString="weeks"

			if(year == 1)
				yearString = "year"
			end
			if(week == 1)
				weekString = "week"
			end

			if(year>0 and week>0)
				description.concat("#{year} #{yearString} and #{week} #{weekString} experience")
			elsif(year>0)
				description.concat("#{year} #{yearString} experience")
			elsif(week>0)
				description.concat("#{week} #{weekString} experience")
			end
		end

		#Patch
		if(currentParticipant.usabilityPatches.nil?)
			description.concat(", no usability patch info")
		else
			patchString = "patches"
			if(currentParticipant.usabilityPatches==1)
				patchString = "patch"
			end
			description.concat(", #{currentParticipant.usabilityPatches} usability #{patchString}")
		end
		#Consensus Threads
		threadString = "threads"
		if(num==1)
			threadString = "thread"
		end
		description.concat(", #{num} closed #{threadString}")

		#Recent Participation
		date2 = Time.now
		days = 0
		if(recency != 0 && !(recency.nil?))
			date1 = DateTime.rfc3339(recency.to_s)
			days = distance_of_time_in_words(date1, date2)
			description.concat(", last commented on a usability thread #{days} ago")
		else
			description.concat(", not recently commented on a usability thread")
		end
		#Triads
		if(triads != 0 && !(triads.nil?))
			description.concat(", has previously interacted with #{triads} of the current participants.")
		else
			description.concat(", no previous interactions with current participants.")
		end
	=begin   random = 1+Random.rand(6)
	if(num < 3 && experienceInfo == 1)
	description.concat(", no previous interactions with current participants.")
	else
	numTriads = 1+Random.rand(12)
	triadString = "participants"
	#if(numTriads==1)
	#  triadString = "participant"
	#end
	description.concat(", has previously interacted with #{numTriads} of the current #{triadString}.")
	end
	=end
	end

	def find_participant_consensus(p_id)
		adapter = DataMapper.repository(:default).adapter
		res = adapter.select("SELECT COUNT(t2.status) AS cb FROM (networks AS t1 INNER JOIN issues AS t2 ON t1.issue_id=t2.id) WHERE (t2.status LIKE 'closed%' OR t2.status LIKE 'fix%') AND t1.participant_id=#{p_id};")
		return res[0]
	end

	def find_participant_recency(p_id)
		adapter = DataMapper.repository(:default).adapter
		res = adapter.select("SELECT max(t1.commented_at) FROM (networks AS t1 INNER JOIN issues AS t2 ON t1.issue_id=t2.id) WHERE t1.participant_id=#{p_id};")
		return res[0]
	end

	def find_participant_triad(p_id)
		issueid = Issue.first(:link => link).id
		adapter = DataMapper.repository(:default).adapter
		res = adapter.select("SELECT COUNT(t1.target_id) AS tr FROM (participant_networks AS t1 INNER JOIN networks AS t2 ON t1.target_id=t2.participant_id) WHERE t1.source_id=#{p_id} AND t2.issue_id=#{issueid};")
		res2 = adapter.select("SELECT COUNT(t1.source_id) FROM (participant_networks AS t1 INNER JOIN networks AS t2 ON t1.source_id=t2.participant_id) WHERE t1.target_id=#{p_id} AND t2.issue_id=#{issueid};")
		return res[0]+res2[0]
	end

	#randomly selects 10 participants between 100 experienced members who are not
	# participating in this thread
	def find_experienced_potential_participants
		adapter = DataMapper.repository(:default).adapter
		issueid = Issue.first(:link => link).id
		res = adapter.select("SELECT id FROM participants WHERE NOT EXISTS (SELECT participant_id, issue_id FROM networks WHERE networks.participant_id=participants.id AND networks.issue_id=#{issueid}) ORDER BY CASE WHEN experience IS NULL THEN 1 ELSE 0 END,experience DESC LIMIT 20;")
		potentials = Array.new
		indx = 0
		res.each do |p_id|
			currentParticipant = Participant.first(:id=>p_id);

			currentPInfo=Hash.new
			currentPInfo["author"]=currentParticipant.user_name
			currentPInfo["authorLink"]=currentParticipant.link
			consensus = find_participant_consensus(p_id)
			triads = find_participant_triad(p_id)
			recency = find_participant_recency(p_id)
			currentPInfo["description"]= gather_participant_info_description(currentParticipant, consensus, recency, triads)

			potentials.push currentPInfo
			indx = indx + 1
			break if indx == 20
		end
		return potentials
	end

	#randomly selects 10 participants between 100 who have submitted patches
	def find_patchsubmitter_potential_participants
		adapter = DataMapper.repository(:default).adapter
		issueid = Issue.first(:link => link).id
		res = adapter.select("SELECT id FROM participants WHERE NOT EXISTS (SELECT participant_id, issue_id FROM networks WHERE networks.participant_id=participants.id AND networks.issue_id=#{issueid}) ORDER BY CASE WHEN usability_patches IS NULL THEN 1 ELSE 0 END, usability_patches DESC LIMIT 20;")
		indx = 0
		potentials = Array.new
		res.each do |p_id|
			currentParticipant = Participant.first(:id=>p_id);

			currentPInfo=Hash.new
			currentPInfo["author"]=currentParticipant.user_name
			currentPInfo["authorLink"]=currentParticipant.link
			consensus = find_participant_consensus(p_id)
			recency = find_participant_recency(p_id)
			triads = find_participant_triad(p_id)
			currentPInfo["description"]= gather_participant_info_description(currentParticipant, consensus, recency,
			# triads)#Time.now)

			potentials.push currentPInfo
			indx = indx + 1
			break if indx == 20
		end

		return potentials
	end

	#randomly selects 10 participants between 100 who create triads with current
	# participants
	def find_triad_potential_participants
		#TODO: write this function
		adapter = DataMapper.repository(:default).adapter
		issueid = Issue.first(:link => link).id
		res = adapter.select("SELECT t1.source_id, COUNT(t1.target_id) AS tr FROM (participant_networks AS t1 INNER JOIN networks AS t2 ON t2.participant_id=t1.target_id) WHERE (t2.issue_id=#{issueid}) AND t1.source_id IN (SELECT id FROM participants WHERE NOT EXISTS (SELECT participant_id, issue_id FROM networks WHERE networks.participant_id=participants.id AND networks.issue_id=#{issueid})) GROUP BY t1.source_id ORDER BY tr DESC LIMIT 10;")

		res2 = adapter.select("SELECT t1.target_id, COUNT(t1.source_id) AS tr FROM (participant_networks AS t1 INNER JOIN networks AS t2 ON t2.participant_id=t1.source_id) WHERE (t2.issue_id=#{issueid}) AND t1.target_id IN (SELECT id FROM participants WHERE NOT EXISTS (SELECT participant_id, issue_id FROM networks WHERE networks.participant_id=participants.id AND networks.issue_id=#{issueid})) GROUP BY t1.target_id ORDER BY tr DESC LIMIT 10;")

		res.concat(res2)

		indx = 0
		potentials = Array.new
		res.each do |row|
			currentParticipant = Participant.first(:id=>row[0]);

			currentPInfo=Hash.new
			currentPInfo["author"]=currentParticipant.user_name
			currentPInfo["authorLink"]=currentParticipant.link
			consensus = find_participant_consensus(row[0])
			recency = find_participant_recency(row[0])
			triads = find_participant_triad(row[0])
			currentPInfo["description"]= gather_participant_info_description(currentParticipant, consensus, recency,
			# triads)#Time.now)

			potentials.push currentPInfo
			indx = indx + 1
			break if indx == 20
		end

		return potentials
	end

	#randomly selects 10 participants between 100 who have participated in threads
	# that reached consensus
	def find_consensus_potential_participants
		adapter = DataMapper.repository(:default).adapter
		issueid = Issue.first(:link => link).id
		res = adapter.select("SELECT networks.participant_id as id, COUNT(networks.participant_id) as total
                          FROM networks, issues
                          WHERE networks.issue_id=issues.id
                          AND (issues.status LIKE 'closed%' OR issues.status LIKE 'fix%')
                          AND networks.participant_id NOT IN (SELECT networks.participant_id
                              FROM networks
                              WHERE networks.issue_id=#{issueid})
                          GROUP BY networks.participant_id
                          ORDER BY total DESC LIMIT 20;")
=begin
adapter.select("SELECT t1.participant_id, COUNT(t2.status) AS cb FROM (networks
# AS t1 INNER JOIN issues AS t2 ON t1.issue_id=t2.id) WHERE (t2.status LIKE
# 'closed%' OR t2.status LIKE 'fix%') AND t1.participant_id IN (SELECT id FROM
# participants WHERE NOT EXISTS (SELECT participant_id, issue_id FROM networks
# WHERE networks.participant_id=participants.id AND
# networks.issue_id=#{issueid})) GROUP BY participant_id ORDER BY cb DESC;")
=end
		indx = 0
		potentials = Array.new
		res.each do |row|
			currentParticipant = Participant.first(:id=>row[0]);

			currentPInfo=Hash.new
			currentPInfo["author"]=currentParticipant.user_name
			currentPInfo["authorLink"]=currentParticipant.link
			recency = find_participant_recency(row[0])
			triads = find_participant_triad(row[0])
			currentPInfo["description"]= gather_participant_info_description(currentParticipant, row[1], recency, triads)

			potentials.push currentPInfo
			indx = indx + 1
			break if indx == 20
		end

		return potentials
	end

	#randomly selects 10 participants between 100 who have RECENTLY participated in
	# threads
	def find_recent_potential_participants
		adapter = DataMapper.repository(:default).adapter
		issueid = Issue.first(:link => link).id
		res = adapter.select("SELECT t1.participant_id, MAX(t1.commented_at) as mx FROM networks AS t1 WHERE t1.participant_id NOT IN (SELECT networks.participant_id FROM networks WHERE networks.issue_id=#{issueid}) GROUP BY t1.participant_id ORDER BY mx DESC;")

=begin
res = adapter.select("SELECT t1.participant_id, MAX(t1.commented_at) as mx FROM
# (networks AS t1 INNER JOIN issues AS t2 ON t1.issue_id=t2.id) WHERE
# t1.participant_id IN (SELECT id FROM participants WHERE NOT EXISTS (SELECT
# participant_id, issue_id FROM networks WHERE
# networks.participant_id=participants.id AND networks.issue_id=#{issueid}))
# GROUP BY participant_id ORDER BY mx DESC;")
=end
		indx = 0
		potentials = Array.new
		res.each do |row|
			currentParticipant = Participant.first(:id=>row[0]);

			currentPInfo=Hash.new
			currentPInfo["author"]=currentParticipant.user_name
			currentPInfo["authorLink"]=currentParticipant.link
			consensus = find_participant_consensus(row[0])
			triads = find_participant_triad(row[0])
			currentPInfo["description"]= gather_participant_info_description(currentParticipant, consensus, row[1], triads)

			potentials.push currentPInfo
			indx = indx + 1
			break if indx == 20
		end

		return potentials
	end

	#randomly selects 10 participants between 100 who have RECENTLY participated in
	# threads that reached consensus
	def find_recentconsensus_potential_participants
		adapter = DataMapper.repository(:default).adapter
		issueid = Issue.first(:link => link).id
		res = adapter.select("SELECT t1.participant_id, COUNT(t2.status) AS cb, t1.commented_at FROM (networks AS t1 INNER JOIN issues AS t2 ON t1.issue_id=t2.id) WHERE (t2.status LIKE 'closed%' OR t2.status LIKE 'fix%') AND t1.participant_id IN (SELECT id FROM participants WHERE NOT EXISTS (SELECT participant_id, issue_id FROM networks WHERE networks.participant_id=participants.id AND networks.issue_id=#{issueid})) GROUP BY participant_id ORDER BY commented_at DESC;")
		indx = 0
		potentials = Array.new
		res.each do |row|
			currentParticipant = Participant.first(:id=>row[0]);

			currentPInfo=Hash.new
			currentPInfo["author"]=currentParticipant.user_name
			currentPInfo["authorLink"]=currentParticipant.link
			currentPInfo["description"]= gather_participant_info_description(currentParticipant, row[1], row[2])

			potentials.push currentPInfo
			indx = indx + 1
			break if indx == 20
		end

		return potentials
	end

	#find conversations in a new thread
	def find_conversations(start,convoLen,maxContinuous)
		comments = Comment.all(:issue_id=>id)
		x=start
		while(x<comments.size-convoLen)
			tagComments=Array.new     #array to store comments that will get tagged
			currAuthor=comments[x].participant  #currAuthor and secAuthor keep track of the 2
			# conversation participants
			secAuthor=currAuthor
			pos=x         #current position in comments array
			numLastAuth=0       #number of consecutive posts made by the currAuthor
			isConvo=true        #boolean to keep of whether or not it is a conversation
			firstIter=true        #boolean to keep track of first iteration of the while loop
			grace=false       #boolean that keeps track of whether a comment was skipped over
			# eg: ABACBA where A and B are the conversation participants and C is skipped
			while (isConvo && (tagComments.length < convoLen))
				maxPosts=pos+maxContinuous
				while ((tagComments.length < convoLen) && (comments[pos].participant==currAuthor))
					tagComments.push(comments[pos])
					numLastAuth+=1
					pos+=1
				end
				if(pos>maxPosts || pos==maxPosts-maxContinuous || numLastAuth > maxContinuous)
				numLastAuth=0
				isConvo=false
				end
				if(firstIter)
					countPosts=0
					countAuth=1
					iter=pos
					currPostAuth=comments[pos].participant
					while(iter<x+convoLen)
						if(currPostAuth==comments[iter].participant)
						countPosts+=1
						else
						countAuth+=1
						end
						iter+=1
					end
					if(countPosts==1)
					grace=true
					pos+=1
					else
					numLastAuth=0
					end
					currAuthor=comments[pos].participant
					firstIter=false
					if(currAuthor.user_name == "System Message" || secAuthor.user_name == "System Message")
					isConvo=false
					end
				else
					if(!grace && (comments[pos].participant!=currAuthor && comments[pos].participant!=secAuthor))
						grace=true
						pos+=1
						if(pos >= comments.size-convoLen)
						break
						elsif(comments[pos].participant!=comments[pos-2].participant)
						numLastAuth=0
						end
					elsif(tagComments.length < convoLen)
					numLastAuth=0
					end
				temp=currAuthor
				currAuthor=secAuthor
				secAuthor=temp
				end
			end
			if(isConvo && tagComments.size == convoLen)
				if((comments[pos-1].participant!=currAuthor) && (comments[pos-1].participant!=secAuthor))
					if((comments[pos].participant==currAuthor) || (comments[pos].participant==secAuthor))
						if(comments[pos-2].participant != comments[pos].participant)
						numLastAuth=1
						tagComments.push(comments[pos])
						pos+=1
						elsif(numLastAuth<maxContinuous)
						numLastAuth+=1
						tagComments.push(comments[pos])
						pos+=1
						end
					end
				elsif(comments[pos].participant!=comments[pos-1].participant)
				numLastAuth=0
				end
				continue=true
				while(continue && (pos<comments.size) && ((comments[pos].participant==currAuthor) || (comments[pos].participant==secAuthor)))
					if(comments[pos].participant==comments[pos-1].participant)
						if(numLastAuth<maxContinuous)
						numLastAuth+=1
						tagComments.push(comments[pos])
						pos+=1
						else
						continue=false
						end
					else
					numLastAuth=1
					tagComments.push(comments[pos])
					pos+=1

					end
				end
				tagComments.each do |curr|
					curr.tags.first_or_create({:name=>"conversation", :participant => curr.participant})
				end
			x=pos
			else
			x+=1
			end
		end
	end

	def find_ideas(start,numCheck,minRank,refVal,imgVal,toneVal,patchVal,frequentPostVal,experienceVal)
		#Rails.logger.info "start: #{start}, numCheck: #{numCheck}, minRank:
		# #{minRank},refVal: #{refVal},imgVal: #{imgVal},toneVal: #{toneVal},patchVal:
		# #{patchVal}"
		scores = {}
		comments = Comment.all(:issue_id=>id)
		references=Array.new(comments.length) {Array.new}
		tonal=Array.new(comments.length){Boolean}
		x=start
		tokenizer = TactfulTokenizer::Model.new
		commentAuthors = {}
		comments.each do |comment|
			user = comment.participant.user_name
			if(commentAuthors.key?(user))
			commentAuthors[user]+=1
			else
			commentAuthors[user]=1
			end
		end
		averagePostsByUser = 0
		commentAuthors.each do |key, value|
			averagePostsByUser += value
		end
		averagePostsByUser = (averagePostsByUser/commentAuthors.length).to_i
		while(x<comments.length)
			commentXParticipant = comments[x].participant
			tonal[x]=false
			numbers = comments[x].content.scan(/\d+/)
			numbers.each do |num|
				if(contains_post_num_ref(comments[x].content,num))
					if(!tonal[num] && isTonal(tokenizer,comments[x].content,comments[num].title))
					tonal[num]=true
					end
					references[num].push(comments[i])
				end
			end
			i=x+1
			stop=(x+numCheck)+1
			if(stop>comments.length)
			stop=comments.length
			end
			checkNames=true
			while(i<stop)
				if(checkNames && comments[i].content)
					if(comments[i].participant == commentXParticipant)
					checkNames=false
					elsif(comments[i].content.include?(commentXParticipant.user_name))
						if(!tonal[x] && isTonal(tokenizer,comments[i].content,commentXParticipant.user_name))
						tonal[x]=true
						end
					references[x].push(comments[i])
					elsif(!commentXParticipant.first_name.eql?("") && comments[i].content.include?(commentXParticipant.first_name))
						if(!tonal[x] && isTonal(tokenizer,comments[i].content,commentXParticipant.first_name))
						tonal[x]=true
						end
					references[x].push(comments[i])
					end
				end
				i+=1
			end
			x+=1
		end
		x=start
		while(x<comments.length)
			commentXParticipant = comments[x].participant
			experiencedUsers = find_top_experienced_participants()
			#IF a single person refered to a comment more than once, it needs to be removed.
			ref_participants=references[x].uniq{|com| com.participant}
			frequentPosts = averagePostsByUser < commentAuthors[commentXParticipant.user_name]
			rank = (ref_participants.length * refVal) + ((tonal[x] ? 1 : 0) * toneVal) + ((comments[x].has_image ? 1 : 0) * imgVal) + ((comments[x].patch ? 1 : 0) * patchVal) + ((frequentPosts ? 1 : 0) * frequentPostVal)  + ((experiencedUsers.include?(commentXParticipant.user_name) ? 1 : 0) * experienceVal)
			if(rank > minRank)
				statusStr = "Ongoing"
				if(comments[x].patch)
					statusStr = "Implemented"
				end
				idea = Idea.first_or_create({:comment=> comments[x]},{:status=>statusStr})
				comments[x].ideasource = idea
				tag = Tag.first_or_create({:name => "idea", :comment => comments[x], :participant => commentXParticipant})
				comments[x].save
				references[x].each do |reference|
					reference.idea = idea
					reference.save
				end
			idea.save
			end
			x+=1
		end
	end

	def find_top_experienced_participants
		adapter = DataMapper.repository(:default).adapter
		issueid = Issue.first(:link => link).id
		res = adapter.select("SELECT id FROM participants WHERE NOT EXISTS (SELECT participant_id, issue_id FROM networks WHERE networks.participant_id=participants.id AND networks.issue_id=#{issueid}) ORDER BY experience DESC;")
		experiencedUsers = Array.new
		indx = 0
		amount = res.size * 0.05
		res.each do |p_id|
			currentParticipant = Participant.first(:id=>p_id);
			experiencedUsers.push currentParticipant.user_name
			indx = indx + 1
			break if indx >= amount
		end
		return experiencedUsers
	end

	def contains_post_num_ref(content,postnum)
=begin
x=0
subContent = content.gsub( "@", "#")
contentArray = subContent.split("#")
index = 1
if(subContent.starts_with?("#"))
index = 0
end
contentArray.from(index).each do |curr|
numString = curr.slice(0,3)
if(numString[/\d+/].to_i == postnum)
return true
end
end
return false

=end
		charArray=content.chars.to_a
		x=0
		while(x<charArray.length)
			if(charArray[x]=='#'||charArray[x]=='@')
				x+=1
				ref=""
				while(charArray[x].to_i !=0 || charArray[x] == "0")
					ref << charArray[x]
					x+=1
				end
				if(ref.to_i==postnum)
				return true
				end
			end
			x+=1
		end
		return false

	end

	def isTonal(tokenizer,content,reference)
		sentences = tokenizer.tokenize_text(content)
		iter=0
		while(iter<sentences.length)
			if(sentences[iter].include?(reference))
				if(sentences[iter].length == reference.length)
					if((sentences.length > iter+1) && (sentences[iter+1] =~ /(?:like|liked|prefer|glad|cool|nice|nicely|good|consensus|rather|well)/i) || sentences[iter+1].include?('+1'))
					return true
					end
					if((sentences.length > iter+2) && (sentences[iter+2] =~ /(?:like|liked|prefer|glad|cool|nice|nicely|good|consensus|rather|well)/i) || sentences[iter+2].include?('+1'))
					return true
					end
				elsif((sentences[iter] =~ /(?:like|liked|prefer|glad|cool|nice|nicely|good|consensus|rather|well)/i) || sentences[iter].include?('+1'))
				return true
				end
			end
			iter+=1
		end
	end

	def find_recent_potential_participants_Dmapper
		adapter = DataMapper.repository(:default).adapter
		issueid = Issue.first(:link => link).id
		res = adapter.select("SELECT participant_id, commented_at FROM networks WHERE issue_id<>" + issueid.to_s + " ORDER BY commented_at DESC LIMIT 20;")

		potentials = Array.new
		res.each do |row|
			currentParticipant = Participant.first(:id=>row.participant_id);

			currentPInfo=Hash.new
			currentPInfo["author"]=currentParticipant.user_name
			currentPInfo["authorLink"]=currentParticipant.link
			consensus = find_participant_consensus(row.participant_id)
			triads = find_participant_triad(row.participant_id)
			currentPInfo["description"]= gather_participant_info_description(currentParticipant, consensus, row.commented_at, triads)

			potentials.push currentPInfo
		end
		return potentials
	end

	def find_consensus_potential_participants_Dmapper
		adapter = DataMapper.repository(:default).adapter
		issueid = Issue.first(:link => link).id
		res = adapter.select("SELECT networks.participant_id as id, COUNT(networks.participant_id) as total FROM networks, issues WHERE networks.issue_id=issues.id AND networks.issue_id<>" + issueid.to_s + " AND (issues.status LIKE 'closed%' OR issues.status LIKE 'fix%') GROUP BY networks.participant_id ORDER BY total DESC LIMIT 20;")

		potentials = Array.new
		res.each do |row|
			currentParticipant = Participant.first(:id=>row.id);

			currentPInfo=Hash.new
			currentPInfo["author"]=currentParticipant.user_name
			currentPInfo["authorLink"]=currentParticipant.link
			recency = find_participant_recency(row.id)
			triads = find_participant_triad(row.id)
			currentPInfo["description"]= gather_participant_info_description(currentParticipant, row.total, recency, triads)

			potentials.push currentPInfo
		end
		return potentials
	end

end

