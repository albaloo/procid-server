class Idea
  include DataMapper::Resource
  property :id,       Serial
  property :status, String

  belongs_to :comment, :required=>false

  # comment has n related comments if it's an idea
  has n, :comments#, :required => false

  # comment has n criteria status if it's an idea
  has n, :criteria_statuses#, :required => false

  def getSortedCriteriaStatuses
	result = criteria_statuses.sort {|x,y| x.comment.commented_at <=> y.comment.commented_at}
	return result
  end

  def getRelatedComments
    result = Array.new
    result.concat(criteria_statuses.map{|x| x.comment})
    result.concat(comments)    
    result = result.sort {|x,y| x.commented_at <=> y.commented_at}
    return result
  end
  
  def destroy_idea
  	if(destroy)									#return true if idea has already been destroyed
  		return true
  	end
  	Tag.first(:comment => comment).destroy		#destroy associated tag	
  	criteria_statuses.comment.destroy			#destroy associated criteria statuses and their comments
  	criteria_statuses.comment
  	criteria_statuses.destroy
  	com=comment									#remove association to comment the idea was created in
  	com.ideasource=nil
  	com.save
  	comment=nil
  	comments.each do |t|						#remove association to references
  		t.idea=nil
  		t.save
  	end
  	comments.clear
  	return destroy								#call destroy for this idea and return result
  end
  
end
