class Issue
  include DataMapper::Resource
  include ActionView::Helpers::DateHelper
  property :id,           Serial
  property :title,        String,:length=>1000
  property :status,	String
  property :link, 	String,:length=>500,   :required => true
  property :created_at,	DateTime, :required => false
  
  belongs_to :participant
  has n, :comments, :required => false
  has n, :criterias, :required => false

  def find_num_previous_comments
    return Comment.count(:issue_id=>id);
  end

  def getNewCommentTitle
    num = Comment.count(:issue_id=>id)+1;
    return "#"+num.to_s;
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
    potentials.concat(find_consensus_potential_participants_Dmapper)
    potentials.concat(find_recent_potential_participants_Dmapper)

    potentials = potentials.uniq
    return potentials.sample(30)
  end
  
  #select all participants who are not participating in this thread
  def find_all_potential_participants
    adapter = DataMapper.repository(:default).adapter
    issueid = Issue.first(:link => link).id
    command = "SELECT id FROM participants WHERE NOT EXISTS (SELECT participant_id, issue_id FROM networks WHERE networks.participant_id=participants.id AND networks.issue_id=#{issueid});"
    potentials = adapter.select(command)
    return potentials
  end

  def gather_participant_info_description (currentParticipant, num, recency)
    description = ""
    #Experience
    if(currentParticipant.experience.nil?)
      description.concat("no experience info")
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
    patchString = "patches"
    if(currentParticipant.usabilityPatches==1)
      patchString = "patch"
    end
    description.concat(", #{currentParticipant.usabilityPatches} usability #{patchString}")

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
      description.concat(", recent participation #{days} ago.")
    else
      description.concat(", not recently in a usability thread.")
    end
    

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
  #randomly selects 10 participants between 100 experienced members who are not participating in this thread
  def find_experienced_potential_participants
    adapter = DataMapper.repository(:default).adapter
    issueid = Issue.first(:link => link).id
    res = adapter.select("SELECT id FROM participants WHERE NOT EXISTS (SELECT participant_id, issue_id FROM networks WHERE networks.participant_id=participants.id AND networks.issue_id=#{issueid}) ORDER BY experience DESC;")
    potentials = Array.new
    indx = 0	
    res.each do |p_id|
      currentParticipant = Participant.first(:id=>p_id);

      currentPInfo=Hash.new
      currentPInfo["author"]=currentParticipant.user_name
      currentPInfo["authorLink"]=currentParticipant.link
      consensus = find_participant_consensus(p_id) 
      recency = find_participant_recency(p_id)
      currentPInfo["description"]= gather_participant_info_description(currentParticipant, consensus, recency)
      
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
    res = adapter.select("SELECT id FROM participants WHERE NOT EXISTS (SELECT participant_id, issue_id FROM networks WHERE networks.participant_id=participants.id AND networks.issue_id=#{issueid}) ORDER BY usability_patches DESC;")
    indx = 0
    potentials = Array.new
    res.each do |p_id|
      currentParticipant = Participant.first(:id=>p_id);

      currentPInfo=Hash.new
      currentPInfo["author"]=currentParticipant.user_name
      currentPInfo["authorLink"]=currentParticipant.link
      consensus = find_participant_consensus(p_id) 
      recency = find_participant_recency(p_id)
      currentPInfo["description"]= gather_participant_info_description(currentParticipant, consensus, recency)#Time.now)

      potentials.push currentPInfo
      indx = indx + 1
      break if indx == 20
    end			

    return potentials
  end

  #randomly selects 10 participants between 100 who create triads with current participants
  def find_triadmakers_potential_participants
  #TODO: write this function
    adapter = DataMapper.repository(:default).adapter
    issueid = Issue.first(:link => link).id
    res = adapter.select("SELECT id FROM participants WHERE NOT EXISTS (SELECT participant_id, issue_id FROM networks WHERE networks.participant_id=participants.id AND networks.issue_id=#{issueid}) ORDER BY usability_patches DESC;")
    indx = 0
    potentials = Array.new
    res.each do |p_id|
      potentials = potentials.to_a.push p_id
      indx = indx + 1
      break if indx == 20
    end			

    return potentials
  end

  #randomly selects 10 participants between 100 who have participated in threads that reached consensus
  def find_consensus_potential_participants
    adapter = DataMapper.repository(:default).adapter
    issueid = Issue.first(:link => link).id
    res = adapter.select("SELECT t1.participant_id, COUNT(t2.status) AS cb FROM (networks AS t1 INNER JOIN issues AS t2 ON t1.issue_id=t2.id) WHERE (t2.status LIKE 'closed%' OR t2.status LIKE 'fix%') AND t1.participant_id IN (SELECT id FROM participants WHERE NOT EXISTS (SELECT participant_id, issue_id FROM networks WHERE networks.participant_id=participants.id AND networks.issue_id=#{issueid})) GROUP BY participant_id ORDER BY cb DESC;")
    indx = 0
    potentials = Array.new
    res.each do |row|
      currentParticipant = Participant.first(:id=>row[0]);

      currentPInfo=Hash.new
      currentPInfo["author"]=currentParticipant.user_name
      currentPInfo["authorLink"]=currentParticipant.link
      recency = find_participant_recency(row[0])
      currentPInfo["description"]= gather_participant_info_description(currentParticipant, row[1], recency)
      
      potentials.push currentPInfo
      indx = indx + 1
      break if indx == 20
    end			

    return potentials
  end

  #randomly selects 10 participants between 100 who have RECENTLY participated in threads
  def find_recent_potential_participants
    adapter = DataMapper.repository(:default).adapter
    issueid = Issue.first(:link => link).id
    res = adapter.select("SELECT t1.participant_id, MAX(t1.commented_at) as mx FROM (networks AS t1 INNER JOIN issues AS t2 ON t1.issue_id=t2.id) WHERE t1.participant_id IN (SELECT id FROM participants WHERE NOT EXISTS (SELECT participant_id, issue_id FROM networks WHERE networks.participant_id=participants.id AND networks.issue_id=#{issueid})) GROUP BY participant_id ORDER BY mx DESC;")
    indx = 0
    potentials = Array.new
    res.each do |row|
      currentParticipant = Participant.first(:id=>row[0]);

      currentPInfo=Hash.new
      currentPInfo["author"]=currentParticipant.user_name
      currentPInfo["authorLink"]=currentParticipant.link
      consensus = find_participant_consensus(row[0])
      currentPInfo["description"]= gather_participant_info_description(currentParticipant, consensus, row[1])
      
      potentials.push currentPInfo
      indx = indx + 1
      break if indx == 20
    end			

    return potentials
  end

  #randomly selects 10 participants between 100 who have RECENTLY participated in threads that reached consensus
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
	  	tagComments=Array.new			#array to store comments that will get tagged
  		currAuthor=comments[x].participant	#currAuthor and secAuthor keep track of the 2 conversation participants
  		secAuthor=currAuthor
  		pos=x					#current position in comments array
  		numLastAuth=0				#number of consecutive posts made by the currAuthor
  		isConvo=true				#boolean to keep of whether or not it is a conversation
  		firstIter=true				#boolean to keep track of first iteration of the while loop
  		grace=false				#boolean that keeps track of whether a comment was skipped over eg: ABACBA where A and B are the conversation participants and C is skipped
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
  				curr.tags.first_or_create(:name=>"conversation")
  			end
  			x=pos
  		else 
  			x+=1
  		end
  	end
  end


def find_ideas(start,numCheck,minRank,refVal,imgVal,toneVal,patchVal)
        Rails.logger.debug "start: #{start}, numCheck: #{numCheck}, minRank: #{minRank},refVal: #{refVal},imgVal: #{imgVal},toneVal: #{toneVal},patchVal: #{patchVal}"
    comments = Comment.all(:issue_id=>id)
    references=Array.new(comments.length) {Array.new}
    tonal=Array.new(comments.length){Boolean}
    x=start
    tokenizer = TactfulTokenizer::Model.new
    while(x<comments.length)
        tonal[x]=false
        i=x+1
        stop=(x+numCheck)+1
        if(stop>comments.length)
            stop=comments.length
        end
        checkNames=true
        while(i<comments.length)
            if(contains_post_num_ref(comments[i].content,comments[x].title[/\d+/].to_i))
                if(!tonal[x] && isTonal(tokenizer,comments[i].content,comments[x].title))
                    tonal[x]=true
                end
                references[x].push(comments[i])
            elsif(i<stop)
                if(checkNames && comments[i].participant == comments[x].participant)
                    checkNames=false
                end
                if(checkNames && comments[i].content.include?(comments[x].participant.user_name))
                    if(!tonal[x] && isTonal(tokenizer,comments[i].content,comments[x].participant.user_name))
                        tonal[x]=true
                    end
                    references[x].push(comments[i])
                elsif(checkNames && comments[i].content.include?(comments[x].participant.first_name))
                    if(!tonal[x] && isTonal(tokenizer,comments[i].content,comments[x].participant.first_name))
                        tonal[x]=true
                    end
                    references[x].push(comments[i])
                end
            end
            i+=1
        end
        rank = (references[x].length * refVal) + ((tonal[x] ? 1 : 0) * toneVal) + ((comments[x].has_image ? 1 : 0) * imgVal) + ((comments[x].patch ? 1 : 0) * patchVal)
        if(rank > minRank)
            idea = Idea.first_or_create({:comment=> comments[x]},{:status=>"Ongoing"})    
            comments[x].ideasource = idea
            tag = Tag.first_or_create({:name => "idea", :comment => comments[x]})
            comments[x].save
            references[x].each do |reference|        
              reference.idea = idea
              reference.save
            end
        end
        if(x==22)
  					tmp_file = "#{Rails.root}/out2.txt"
					File.open(tmp_file, 'wb') do |f|
						f.write references[22]
					end
			end
        x+=1
    end                
  end
  def contains_post_num_ref(content,postnum)
  	charArray=content.chars.to_a
  	x=0
  	while(x<charArray.length)
  		if(charArray[x]=='#'||charArray[x]=='@')
  			x+=1
  			ref=""
  			while(charArray[x].to_i !=0)
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

  

=begin
  def find_ideas(start,numCheck,minWithImg,minNoImg)
        Rails.logger.debug "start: #{start}, numCheck: #{numCheck}, minWithImg: #{minWithImg}, , minNoImg: #{minNoImg}"
  	comments = Comment.all(:issue_id=>id)
      references=Array.new(comments.length) {Array.new}
      x=start
      while(x<comments.length)
          i=x+1
          stop=(x+numCheck)+1
          if(stop>comments.length)
              stop=comments.length
          end
          checkNames=true
          while(i<stop)
              if(checkNames && comments[i].participant == comments[x].participant)
                  checkNames=false
              end
              if(comments[i].content.include?(comments[x].title) || (checkNames && (comments[i].content.include?(comments[x].participant.first_name || comments[i].content.include?(comments[x].participant.user_name)))))
                  references[x].push(comments[i])
              end
              i+=1
          end
          if(references[x].length>=minNoImg || (comments[x].has_image && references[x].length >= minWithImg))
            idea = Idea.first_or_create({:comment=> comments[x]},{:status=>"Ongoing"})    
            comments[x].ideasource = idea
            tag = Tag.first_or_create({:name => "idea", :comment => comments[x]})
            comments[x].save        
        end
          x+=1
      end            	
  end
=end


def find_recent_potential_participants_Dmapper
    issueid = Issue.first(:link => link).id
    res = Network.all()
    res2 = Network.all(:conditions=>{:issue_id=>issueid})
    indx = 0
    sortedRes = sorted = res.group_by {|x| x.participant_id}.sort_by {|x,list| [list.max_by{|y| y.commented_at}.commented_at,x]}.map{|x| x.second.max_by{|y| y.commented_at}}
    sortedRes = sortedRes.find_all{|x| !(res2.map{|y| y.participant_id}.include?x.participant_id)}
   
    potentials = Array.new
    sortedRes.reverse.each do |row|
      currentParticipant = Participant.first(:id=>row.participant_id);

      currentPInfo=Hash.new
      currentPInfo["author"]=currentParticipant.user_name
      currentPInfo["authorLink"]=currentParticipant.link
      consensus = find_participant_consensus(row.participant_id)
      currentPInfo["description"]= gather_participant_info_description(currentParticipant, consensus, row.commented_at)
      
      potentials.push currentPInfo
      indx = indx + 1
      break if indx == 20
    end			

    return potentials
  end  

  def find_consensus_potential_participants_Dmapper
    issueid = Issue.first(:link => link).id
    res = Network.all(:conditions=>{Network.issue.status.like => "closed%"}) + Network.all(:conditions=>{Network.issue.status.like => "fix%", :issue_id.not=>issueid})
    res2 = Network.all(:conditions=>{:issue_id=>issueid})
    indx = 0
    participantIds = Array.new
    res.each do |row|
      participantIds.push(row.participant_id);
    end

    currentParticipantIds = Array.new
    res2.each do |row|
      currentParticipantIds.push(row.participant_id);
    end

    participantIds=participantIds - currentParticipantIds

    participantIds_counts = participantIds.group_by {|x| x}.sort_by {|x,list| [-list.size,x]}.map{|x| [x.first, x.second.size]}
    potentials = Array.new
    participantIds_counts.each do |row|
      currentParticipant = Participant.first(:id=>row[0]);

      currentPInfo=Hash.new
      currentPInfo["author"]=currentParticipant.user_name
      currentPInfo["authorLink"]=currentParticipant.link
      recency = find_participant_recency(row[0])
      currentPInfo["description"]= gather_participant_info_description(currentParticipant, row[1], recency)
      
      potentials.push currentPInfo
      indx = indx + 1
      break if indx == 20
    end			

    return potentials
  end  

end

