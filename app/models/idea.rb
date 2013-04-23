class Idea
  include DataMapper::Resource
  property :id,       Serial
  property :status, String

  belongs_to :comment, :required=>false

  # comment has n related comments if it's an idea
  has n, :comments, :required => false

  # comment has n criteria status if it's an idea
  has n, :criteria_statuses#, :required => false

end
