#lib/tasks/import-participant.rake
desc "Prepopulate the Participant table"
task :csv_participant_import => :environment do 
  lines = File.new("attributes-participant.txt").readlines
  lines.each do |line|
	values = line.strip.split("\t")
	lastName = ""
	firstName = ""
	numComments = 0
	numPatches = 0
	if(values.length>6)
		lastName = values[6]
	end
	if(values.length>5)
		firstName = values[5]
	end
	numPatches = values[3];
	numComments = values[4];		

	part = Participant.first_or_create({:user_name =>values[0]},{:link=>values[1], :experience=>values[2], :first_name=>firstName, :last_name=>lastName, :usabilityComments => numComments, :usabilityPatches => numPatches})			 
  end
  puts "Finished pre-populating the db with usability participants"

end
