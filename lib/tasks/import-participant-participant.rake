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
		PPNetwork.first_or_create({:source => participant1, :target => participant2, :commented_at => date})	 
	end
  end
#Alan D.	(Gabor Hojtsy,Wed Sep 14 13:23:00 CDT 2011)	(jhodgdon,Wed Sep 14 23:10:00 CDT 2011)	
	puts "Finished pre-populating the db with network information"
end
