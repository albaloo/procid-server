#lib/tasks/import-issue-participant.rake
desc "REfine idea comment connections"
task :csv_idea_comments_refine => :environment do 
  lines = File.new("idea-comments.txt").readlines
  issue = nil
  lines.each do |line|
	if(line.starts_with?("/node/"))
		currentLink = line.strip
		issue = Issue.first({:link=>currentLink})	
	else
		if not(issue.nil?)
			values = line.strip.split("\t")
			puts "idea: #{values[0]}"
			ideaComment = Comment.first({:title =>values[0], :issue=> issue}).ideasource			 
			values.shift
			counter = 0
			values.each do |value|	
				if not(value == "0")	
					innerValues = value.strip.split(", ")
					innerValues.each do |inValue|
						puts "invalue: #{inValue}"
						puts "issue: #{issue.link}"
						curComment = Comment.first({:title =>inValue, :issue=> issue})
						if(counter == 0)
							curComment.tone = "positive"
						elsif(counter == 1)
							curComment.tone = "neutral"
						else
							curComment.tone = "negative"				
						end 
							curComment.idea = ideaComment 
						curComment.save
					end
				end
				counter = counter + 1
			end

		end
	end
  end
	puts "Finished refining idea-comments connections"
end
