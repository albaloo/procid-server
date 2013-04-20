#lib/tasks/import-issue.rake
desc "Prepopulate the Issue table"
task :csv_issue_import => :environment do 
  lines = File.new("attributes-issue.txt").readlines
  lines.each do |line|
	values = line.strip.split("\t")
	creator = Participant.first({:user_name =>values[16]})
	if(creator == nil)
		creator = Participant.first_or_create({:user_name =>"Anonymous"});
	end			 
	Issue.first_or_create({:link => values[1]},{:status =>values[12],:participant=>creator, :title => values[15], :created_at => values[2]})
  end
  puts "Finished pre-populating the db with usability issues."
end

