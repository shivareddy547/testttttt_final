class IssueSlaStatus < ActiveRecord::Base

  belongs_to :project, :class_name => 'Project', :foreign_key => 'issue_sla_status_id'
  belongs_to :tracker, :class_name => 'Tracker', :foreign_key => 'issue_sla_status_id'
  belongs_to :issue_status, :class_name => 'IssueStatus'

  has_one :sla_time, :class_name => 'SlaTime', :foreign_key => 'issue_sla_status_id'

  has_one :parent_status, :class_name => "IssueSlaStatus",  :foreign_key => "old_status_id"
  # belongs_to :old_status, :class_name => "IssueSlaStatus",  :foreign_key => "old_status_id"


  def self.create_project_status(project, params)
    sla_status_ids, timer,tracker_id = params[:status_ids], params[:status_sla],params[:tracker_id]

    project.issue_sla_statuses.map(&:issue_status_id).each do |sla|
      unless sla_status_ids.present? && sla_status_ids.include?(sla.to_s)
        project.issue_sla_statuses.find_by_issue_status_id(sla).delete
      end
    end

    slas = project.issue_sla_statuses
    rec = []
    timer.each {|key, value| rec << key if value=='stop' }
    sla = sla_status_ids.present? ? sla_status_ids : []
    ::IssueStatus.find(sla).each do |p|
      next if slas.any? {|s| s.issue_status_id == p.id }
       state = IssueSlaStatus.create(:issue_status => p, :project=> project)
       state.update_attributes(:sla_timer => timer[state.issue_status.id.to_s],:tracker_id=>tracker_id)
    end
#    project.issue_sla_statuses.find_all_by_issue_status_id(rec).each { |rec| rec.update_attributes(:sla_timer => 'stop') }
    project.issue_sla_statuses.each do |issue_sla|
      if rec.include? issue_sla.issue_status_id.to_s
        issue_sla.update_attributes(:sla_timer => 'stop')
      else
        issue_sla.update_attributes(:sla_timer => 'start')
      end
    end
    project.issue_sla_statuses.reload
  end




  # add severioty to project
  def self.create_or_update_status(project, params)
     priority_ids = params[:status_ids]
    tracker_id = params[:tracker_id]
     if priority_ids.present?
      priority_ids.each do |priority_id|
        if params[:status_sla][priority_id.to_sym].present? && params[:status_sla][priority_id.to_sym] == "start"
          find_sla = IssueSlaStatus.where(:project_id=>project.id,:tracker_id=>tracker_id,:issue_status_id=>priority_id).first_or_create
          find_sla.update_attributes(:sla_timer => 'start')
        else
          find_sla = IssueSlaStatus.where(:project_id=>project.id,:tracker_id=>tracker_id,:issue_status_id=>priority_id).first_or_create
          find_sla.update_attributes(:issue_status_id=>priority_id,:sla_timer => 'stop')
        end
        not_found_slas =  IssueSlaStatus.where(:project_id=>project.id,:tracker_id=>tracker_id).where("issue_status_id  NOT IN (?)",priority_ids)
        if not_found_slas.present?
          not_found_slas.each do |not_found|
            not_found.delete
          end
        end
      end
    else
      IssueSlaStatus.delete_all(:project_id=>project.id,:tracker_id=>tracker_id)
    end

  end





end
