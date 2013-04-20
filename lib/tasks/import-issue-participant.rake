#lib/tasks/import-issue-participant.rake
desc "Prepopulate the Issue and Participant table"
task :csv_network_import => :environment do 
  lines = File.new("relations.txt").readlines
  lines.each do |line|
	values = line.strip.split("\t")
	username = values[0]
	participant = Participant.first_or_create({:user_name =>username})			 
	values.shift
	values.each do |value|		
		innerValues = value.strip.split(",")
		issueName = innerValues[0]
		issueName[0]='';
		issueLink = "/node/" + issueName
		issue = Issue.first({:link => issueLink})
		date = innerValues[1].chop
		Network.first_or_create({:participant => participant, :issue => issue, :commented_at => date})	 
	end
  end
	puts "Finished pre-populating the db with network information"
end
