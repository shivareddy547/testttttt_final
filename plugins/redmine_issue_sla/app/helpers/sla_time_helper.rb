module SlaTimeHelper

  def duration_of_ticket(issue_id, issue_status, old_status)
    s  = IssueStatus.find(issue_status)
    issue = Issue.find issue_id
    tracker_status =  IssueSlaStatus.where(:project_id => issue.project.id, :tracker_id => issue.tracker.id)
    sla_id = tracker_status.find_by_issue_status_id(s.id)
    current_status = tracker_status.find_by_issue_status_id(issue.status_id)
    duration =  return_sla_duration(issue) if check_sla_hours(issue) && current_status.sla_timer == 'start'
    issue.sla_times.create(:issue_sla_status_id => sla_id.id,:user_id => issue.assigned_to_id,  :old_status_id =>(old_status.to_i), :pre_status_duration => 0 )
    if check_sla_hours(issue) && current_status.sla_timer == 'start' && current_status.present?
      issue.sla_times.last.update_attributes(:pre_status_duration => duration)
    end
  end


  # It will return sla pending time to ui
  def return_sla_duration(issue)
    tracker_sla_day =  SlaWorkingDay.where(:project_id => issue.project.id, :tracker_id => issue.tracker.id).last
    f_hr = tracker_sla_day.start_at.split(/\./).first.to_i
    f_min = tracker_sla_day.start_at.split(/\./).last.to_i
    t = Time.now
    slas = issue.sla_times
    if slas.count == 0
      if Time.local(t.year, t.month, t.day, f_hr, f_min) >= issue.created_on.to_time.localtime
        duration =  ((Time.now.localtime - Time.local(t.year, t.month, t.day, f_hr, f_min)) / 60).to_i
      elsif Time.local(t.year, t.month, t.day, f_hr, f_min) <= issue.created_on.to_time.localtime
        duration =  ((Time.now.localtime - issue.created_on.to_time.localtime )/ 60).round
      end
    else
      if slas.last.created_at.to_date == Date.today
        duration =  ((Time.now.localtime - issue.sla_times.last.created_at.localtime) / 60).to_i
      elsif slas.last.created_at != Date.today
        duration =  ((Time.now.localtime - Time.local(t.year, t.month, t.day, f_hr, f_min)) / 60).to_i
      end
    end
    duration * 100 /60
  end


  # Add auto TimeEntry comments
  def retun_time_entry_msg(slatime)
    new_status = slatime.issue_sla_status.issue_status.name
    pre_status = slatime.old_status.issue_status.name #unless slatime.count == 1
    pre_status = pre_status == new_status ? 'New' : pre_status
    "Status was changed from #{pre_status} to #{new_status}"
  end

  # Should return within working hours or not
  def check_sla_hours(issue)
    tracker_sla_day =  SlaWorkingDay.where(:project_id => issue.project.id, :tracker_id => issue.tracker.id).last
    f_hr = tracker_sla_day.start_at.split(/\./).first.to_i
    f_min = tracker_sla_day.start_at.split(/\./).last.to_i
    e_hr = tracker_sla_day.end_at.split(/\./).first.to_i
    e_min = tracker_sla_day.end_at.split(/\./).last.to_i
    t = Time.now
    Time.local(t.year, t.month, t.day, f_hr, f_min) <= Time.now && Time.local(t.year, t.month, t.day, e_hr, e_min) >= Time.now
  end

  # background job it will run end of the day and it does automated timeEntry and spent time as well
  def update_time_entry_end_of_day
    Project.all.collect do |project|
      if project.enabled_modules.map(&:name).include?('redmine_issue_sla')
        project.issues.collect do |issue|
          tracker_sla_day =  SlaWorkingDay.where(:project_id => project.id, :tracker_id => issue.tracker.id).last
          f_hr = tracker_sla_day.start_at.split(/\./).first.to_i
          f_min = tracker_sla_day.start_at.split(/\./).last.to_i
          e_hr = tracker_sla_day.end_at.split(/\./).first.to_i
          e_min = tracker_sla_day.end_at.split(/\./).last.to_i
          if today_holiday?(issue)
            sla = issue.sla_times.last
            t = Time.now
            time = Time.local(t.year, t.month, t.day, e_hr, e_min)
            tracker_status =  IssueSlaStatus.where(:project_id => project.id, :tracker_id => issue.tracker.id)
            current_status = tracker_status.find_by_issue_status_id(issue.status_id)
            if current_status.present? && sla.present? && sla.created_at.to_date == Date.today && sla.issue_sla_status.present? && sla.issue_sla_status.sla_timer =='start'
              duration = ((time - issue.sla_times.last.created_at.localtime)/60).to_i
            elsif !sla.present? && time >= issue.created_on.localtime
              if Time.local(t.year, t.month, t.day, f_hr, f_min) >= issue.created_on.to_time.localtime && issue.sla_times.count == 0
                duration =  ((time - Time.local(t.year, t.month, t.day, f_hr, f_min)) / 60).to_i
              elsif Time.local(t.year, t.month, t.day, f_hr, f_min) <= issue.created_on.to_time.localtime && issue.sla_times.count == 0
                duration =  ((time - issue.created_on.to_time.localtime )/ 60).round
              end
            else
              duration = 0
            end
            if duration > 0
              issue.sla_times.create(:issue_sla_status_id => current_status.id,:user_id => issue.assigned_to_id,  :old_status_id => current_status.id , :pre_status_duration => duration )
              issue.sla_times.first.update_attributes(:old_status_id => issue.sla_times.first.issue_sla_status_id) if issue.sla_times.count == 1
              dur = issue.sla_times.last.pre_status_duration
              total_dur = (dur*100)/60
              hh,mm = total_dur.divmod(100)
              mm =  mm.to_i.to_s.size > 1 ? mm.to_i : "0#{mm.to_i}"
              rec = TimeEntry.new(:project_id => project.id, :issue_id => issue.id, :hours => "#{hh}.#{mm}", :comments => "End of the day time log updated from #{current_status.issue_status.name} status" , :activity_id => 8 , :spent_on => Date.today)
              rec.user_id =  issue.sla_times.last.user_id
              rec.save
              rec.errors
            end
          end
        end
      end
    end
  end

  # It will return SLA pending time to show page
  def sla_time_count(issue)
    if redmine_issue_sla_enabled(issue)
      total = 0
      if issue.estimated_hours.present?
        minute = issue.estimated_hours.to_s.split(/\./).last
        estimated_hours =  issue.estimated_hours.present? ? issue.estimated_hours : 0.0
        first = ((estimated_hours.to_s.split(/\./).first.to_i * 100) + minute.to_i)
        p issue.sla_times.sum('pre_status_duration').to_i, first
        total = first - issue.sla_times.sum('pre_status_duration').to_i
      end
      tracker_status =  IssueSlaStatus.where(:project_id => issue.project.id, :tracker_id => issue.tracker.id)
      current_status = tracker_status.find_by_issue_status_id(issue.status_id).sla_timer
      if current_status == 'start'  && today_holiday?(issue) && check_sla_hours(issue)
        spare_time = return_sla_duration(issue)
        test =   total - spare_time.to_i
        hh,mm = test.abs.divmod(100)
        @sym = test > -1 ? '' : '- '
      else
        @sym = total > -1 ? '' : '- '
        hh,mm = total.abs.divmod(100)
      end
      min = mm.to_s.size == 1 ? "0#{mm}" : mm
      total_dur = "#{@sym}#{hh}.#{min}"
    else
      total_dur =   issue.estimated_hours
    end
    return total_dur
  end

  # make sure today is holiday or not
  def today_holiday?(issue)
    holiday = Date.today
    public_holiday = Setting.plugin_redmine_wktime['wktime_public_holiday']
    tracker_sla_day =  SlaWorkingDay.where(:project_id => issue.project.id, :tracker_id => issue.tracker.id).last
    if tracker_sla_day.present?
      if holiday.wday == 0 && tracker_sla_day.sun == false
        false
      elsif holiday.wday == 1 && tracker_sla_day.mon == false
        false
      elsif holiday.wday == 2 && tracker_sla_day.tue == false
        false
      elsif holiday.wday == 3 && tracker_sla_day.wed == false
        false
      elsif holiday.wday == 4 && tracker_sla_day.thu == false
        false
      elsif holiday.wday == 5 && tracker_sla_day.fri == false
        false
      elsif holiday.wday == 6 && tracker_sla_day.sun == false
        false
      elsif public_holiday.present? && public_holiday.include?(holiday.to_date.strftime('%Y-%m-%d').to_s)
        false
      else
        true
      end
    else
      false
    end
  end

  # To check the project permission list. based on this result response button will shown to user
  def check_project_permission(ids, l)
    projects = Project.find(ids)
    members = []
    permissions = []
    projects.each { |rec| members << rec.member_principals.find_by_user_id(User.current.id)  }
    members.flatten.each do |rec|
      rec.member_roles.each { |rec| permissions << rec.role.permissions } if rec.present?
    end
    if permissions.flatten.present? && permissions.flatten.include?(l.to_sym)
      return true
    else
      return false
    end
  end


  # Check if current project has enabled SLA plugin or not
  def redmine_issue_sla_enabled(issue)
    issue.project.enabled_modules.map(&:name).include?('redmine_issue_sla')
  end

end