require 'dm-rails/middleware/identity_map'
#require 'data_mapper'
#DataMapper.setup(:default, 'mysql://procid:procid@localhost/procid')

class ApplicationController < ActionController::Base
  use Rails::DataMapper::Middleware::IdentityMap
  protect_from_forgery

  #DataMapper.setup(:default, 'mysql://user:password@hostname/database')

end
