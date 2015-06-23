class SlaTime < ActiveRecord::Base
  unloadable
  #
  # has_one :old_status, :class_name => "SlaTime",  :foreign_key => "old_status_id"
  belongs_to :old_status, :class_name => "IssueSlaStatus"

  belongs_to :issue, :class_name => 'Issue', :foreign_key => 'issue_id'
  belongs_to :issue_sla_status, :class_name => 'IssueSlaStatus'

end
