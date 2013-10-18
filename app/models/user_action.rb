class UserAction
  include DataMapper::Resource
  property :id, Serial
  property :actionName, String,:length=>50,:required =>false
  property :oldContentFirst, String,:length=>20000,:required =>false
  property :oldContentSecond, String,:length=>20000,:required =>false
  property :newIDFirst, Integer,:required =>false
  property :newIDSecond, Integer,:required =>false
  property :lastModified, DateTime,:required =>false 

  belongs_to :participant
  belongs_to :issue
end
