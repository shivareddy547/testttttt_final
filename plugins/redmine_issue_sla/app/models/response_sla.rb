class ResponseSla < ActiveRecord::Base
  unloadable
  belongs_to :tracker, :class_name => 'Tracker', :foreign_key => 'tracker_id'
end
