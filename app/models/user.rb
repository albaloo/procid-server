class User
  include DataMapper::Resource
  
  property :id,   Serial
  property :name, String,:length=>500, :required => true
  property :pass, String,:length=>500, :required => true
  
end
