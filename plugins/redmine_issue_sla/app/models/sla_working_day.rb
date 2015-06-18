class SlaWorkingDay < ActiveRecord::Base
  unloadable
  belongs_to :project, :class_name => 'Project', :foreign_key => 'project_id'
  belongs_to :tracker, :class_name => 'Tracker', :foreign_key => 'tracker_id'

def self.update_working_hr_day(project, params)
  working_days, f_hr, f_min, t_hr, t_min,tracker_id = params[:working_days], params[:from_hours], params[:from_min],params[:to_hours], params[:to_min],params[:tracker_id]

  sla_working_day = SlaWorkingDay.where(:project_id=>project.id,:tracker_id=>tracker_id)
  if sla_working_day.present?
      sla = sla_working_day.last
    else
      sla = SlaWorkingDay.new
    end
    days = params[:working_days].present?
    sla.project_id = project.id
    sla.tracker_id = tracker_id
    sla.sun = (days && working_days.keys.include?('1')) ? true : false
    sla.mon = (days && working_days.keys.include?('2')) ? true : false
    sla.tue = (days && working_days.keys.include?('3')) ? true : false
    sla.wed = (days && working_days.keys.include?('4')) ? true : false
    sla.thu = (days && working_days.keys.include?('5')) ? true : false
    sla.fri = (days && working_days.keys.include?('6')) ? true : false
    sla.sat = (days && working_days.keys.include?('7')) ? true : false

    sla.start_at = "#{f_hr}.#{f_min}"
    sla.end_at = "#{t_hr}.#{t_min}"
    sla.save
  end


end
