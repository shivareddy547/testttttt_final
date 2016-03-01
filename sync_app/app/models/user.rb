class User < ActiveRecord::Base
  # establish_connection "sync_prod"
  self.inheritance_column = :_type_disabled
  attr_accessible :lastmodified
  
end