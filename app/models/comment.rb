class Comment
  include DataMapper::Resource
require Rails.root.to_s+"/app/controllers/AlchemyAPI.rb"
  # define our schema
  property :id,   Serial
  property :title, String, :required => true
  property :link, String,:length=>500, :required => true
  property :content,String,:length=>60000
  property :tone,String, :default => "neutral"
  property :commented_at, DateTime
  property :summary, String,:length=>500
  property :patch, Boolean, :default => false
  property :has_image, Boolean, :required => false

  belongs_to :participant

  # comment may belong to an idea
  belongs_to :ideasource, 'Idea', :required => false

  # comment may have 1 idea properties if it's an idea
  #has 1, :idea, :required => false
  belongs_to :idea, :required => false

  # comment may have n tags
  has n, :tags

  belongs_to :issue,:required=>false
  belongs_to :criteria_status, :required=>false

  def updateLink
    link = link.concat(id.to_s)
  end

  def self.findSentiment (currentContent)
	# Create an AlchemyAPI object.
	alchemyObj = AlchemyAPI.new();
	# Load the API key from disk.
	alchemyObj.loadAPIKey(Rails.root.to_s+"/api_key.txt");
	# Get sentiment for a text string.
	result = alchemyObj.TextGetTextSentiment(currentContent, "json");
	parsed_result = ActiveSupport::JSON.decode(result)
	info=parsed_result["docSentiment"]
	return info
  end

  def updateSummary  
    if (summary.nil? || summary.empty?)
      summary = " commented."
      Rails.logger.debug "Roshanak ends"
      if not (ideasource.nil?)
        summary = " proposed an idea."
      elsif patch
        summary = " submitted a patch."
      elsif not (idea.nil?) then
        summary = " commented on " + idea.comment.participant.user_name
	summary.concat(" idea")
      else
        summary = " commented."
      end
	self.update(:summary => summary)
    end
    Rails.logger.debug "Summary doroste:#{summary}"
    return summary
  end

  def findSummary  
      currentSummary = " commented."
      if not (ideasource.nil?)
        currentSummary = " proposed an idea."
      elsif patch
        currentSummary = " submitted a patch."
      elsif not (idea.nil?) then
        currentSummary = " commented on " + idea.comment.participant.user_name
	currentSummary.concat(" idea")
      else
        currentSummary = " commented."
      end
    Rails.logger.debug "Summary doroste:#{summary}"
    return currentSummary
  end


  def getRelatedCommentInfo
    result = Hash.new
    result["title"] = title
    result["link"] = link
    result["content"] = content
    result["tone"] = tone
    result["author"] = participant.user_name		
    return result
  end
end
