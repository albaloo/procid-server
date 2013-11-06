#lib/tasks/import-issue-participant.rake
desc "Prepopulate the Participant and Participant table"
task :csv_pprelations_import => :environment do 
  lines = File.new("pp-relations.txt").readlines
  lines.each do |line|
	values = line.strip.split("\t")
	username = values[0]
	participant1 = Participant.first_or_create({:user_name =>username})			 
	values.shift
	values.each do |value|		
		innerValues = value.strip.split(",")
		participant2Name = innerValues[0]
		participant2Name[0]='';
		participant2 = Participant.first_or_create({:user_name =>participant2Name})			 
		date = innerValues[1].chop
		ParticipantNetwork.first_or_create({:source => participant1, :target => participant2, :commented_at => date})	 
	end
  end
	puts "Finished pre-populating the db with participant-network information"
end
