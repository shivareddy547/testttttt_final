module DashboardHelper

  def get_issues_count(project,fixed_version_id,issue_priority_id)
    @project = Project.find(project)
    issues_for_graph = {}
    issues_array = []
    @issue_statses = IssueStatus.all
    @issue_statses.each do |issue_status|

      issues =  Issue.where("status_id = #{issue_status.id} AND project_id=#{project} AND fixed_version_id=#{fixed_version_id}")

      if issues.present?
        issues_array <<
            ["#{issue_status.name}" , issues.count ]
      end
    end

    return issues_array
  end

  def issuesassignedtome_items(project_id)
    get_sql_filter_query_with_out_and = get_sql_filter_query_with_out_and(project_id)
    Issue.visible.open.where("#{get_sql_filter_query_with_out_and}").
        where(:assigned_to_id => ([User.current.id] + User.current.group_ids),:project_id=>project_id).
        limit(10).
        includes(:status, :project, :tracker, :priority).
        order("#{IssuePriority.table_name}.position DESC, #{Issue.table_name}.updated_on DESC").
        all
  end
  def timelog_items(project_id)
    get_sql_filter_query_with_out_and = get_sql_filter_query_with_out_and(project_id)
    TimeEntry.
        where("#{TimeEntry.table_name}.user_id = ? AND #{TimeEntry.table_name}.project_id = ? AND #{TimeEntry.table_name}.spent_on BETWEEN ? AND ?", User.current.id,project_id, Date.today - 6, Date.today).
        includes(:activity, :project, {:issue => [:tracker, :status]}).where("#{get_sql_filter_query_with_out_and}").
        order("#{TimeEntry.table_name}.spent_on DESC, #{Project.table_name}.name ASC, #{Tracker.table_name}.position ASC, #{Issue.table_name}.id ASC").
        all
  end
  def issueswatched_items(project_id)
    get_sql_filter_query_with_out_and = get_sql_filter_query_with_out_and(project_id)
    Issue.visible.on_active_project.watched_by(User.current.id).recently_updated.where("#{get_sql_filter_query_with_out_and}").where(:project_id=>project_id).limit(10).all
  end
  def calendar_items(startdt, enddt)
    Issue.visible.
        where(:project_id => User.current.projects.map(&:id)).
        where("(start_date>=? and start_date<=?) or (due_date>=? and due_date<=?)", startdt, enddt, startdt, enddt).
        includes(:project, :tracker, :priority, :assigned_to).
        all
  end
  def issuesreportedbyme_items(project_id)
    get_sql_filter_query_with_out_and = get_sql_filter_query_with_out_and(project_id)
    Issue.visible.where("#{get_sql_filter_query_with_out_and}").
        where(:author_id => User.current.id,:project_id=>project_id).
        limit(10).
        includes(:status, :project, :tracker).
        order("#{Issue.table_name}.updated_on DESC").
        all
  end
  def documents_items
    Document.visible.order("#{Document.table_name}.created_on DESC").limit(10).all
  end
  def news_items(project_id)
    News.visible.
        where(:project_id => project_id).
        limit(10).
        includes(:project, :author).
        order("#{News.table_name}.created_on DESC").
        all
  end

  def subProjects(id)
    Project.find_by_sql("select * from projects where parent_id = #{id.to_i}")
  end

  # return an array with the project and subprojects IDs
  def return_ids(id)
    array = Array.new
    array.push(id)
    subprojects = subProjects(id)
    subprojects.each do |project|
      array.push(return_ids(project.id))
    end

    return array.inspect.gsub("[","").gsub("]","").gsub("\\","").gsub("\"","")
  end


  # Get Query without AND

  def get_sql_filter_query_with_out_and(project_id)
    get_sql_for_filter_query = get_sql_for_filter_query(project_id)
    get_sql_for_filter_query.slice! "AND" if get_sql_for_filter_query.present?
    return get_sql_for_filter_query
  end

  # Overdue and Unmanageable tasks

  def get_total_issues(project_id,block_name)
    # stringSqlProjectsSubProjects = return_ids(project_id)

    stringSqlProjectsSubProjects = return_ids(project_id)
    # return Issue.where(:project_id => [stringSqlProjectsSubProjects]).count
    get_sql_for_filter_query=''
    get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(project_id,block_name)
    get_sql_for_filter_query = get_sql_for_filter_query(project_id)
    return  Issue.find_by_sql("select * from issues  where project_id in (#{stringSqlProjectsSubProjects})   #{get_sql_for_filter_query}").count
  end
  def get_total_issues_unmange(project_id,block_name)
    # stringSqlProjectsSubProjects = return_ids(project_id)
    stringSqlProjectsSubProjects = return_ids(project_id)
    # return Issue.where(:project_id => [stringSqlProjectsSubProjects]).count
    get_sql_for_filter_query=''
    get_sql_for_trackers_and_statuses_unmanage = get_sql_for_trackers_and_statuses_unmanage(project_id,block_name)
    get_sql_for_filter_query = get_sql_for_filter_query(project_id)
    return  Issue.find_by_sql("select * from issues  where project_id in (#{stringSqlProjectsSubProjects}) #{get_sql_for_trackers_and_statuses_unmanage}  #{get_sql_for_filter_query}").count
  end



  def get_management_issues(project_id,block_name)
    get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(project_id,block_name)

    stringSqlProjectsSubProjects = return_ids(project_id)
    get_sql_for_filter_query = get_sql_for_filter_query(project_id)
    Issue.find_by_sql("select 1 as id, 'Manageable(s)' as typemanagement, count(1) as totalissues
                                                from issues  where project_id in (#{stringSqlProjectsSubProjects})  #{get_sql_for_filter_query} and due_date is not null
                                                union
                                                select 2 as id, 'Unmanageable(s)' as typemanagement, count(1) as totalissues
                                                from issues  where project_id in (#{stringSqlProjectsSubProjects})  and due_date is null  #{get_sql_for_filter_query};")

  end
  def get_management_issues_unmanage(project_id,block_name)

    get_sql_for_trackers_and_statuses_unmanage = get_sql_for_trackers_and_statuses_unmanage(project_id,block_name)
    stringSqlProjectsSubProjects = return_ids(project_id)
    get_sql_for_filter_query = get_sql_for_filter_query(project_id)
    Issue.find_by_sql("select 1 as id, 'Manageable(s)' as typemanagement, count(1) as totalissues
                                                from issues  where project_id in (#{stringSqlProjectsSubProjects})  #{get_sql_for_trackers_and_statuses_unmanage} #{get_sql_for_filter_query} and (due_date+0) > 0
                                                union
                                                select 2 as id, 'Unmanageable(s)' as typemanagement, count(1) as totalissues
                                                from issues  where project_id in (#{stringSqlProjectsSubProjects})  #{get_sql_for_trackers_and_statuses_unmanage} and ((due_date+0)=0 or due_date is null)  #{get_sql_for_filter_query};")

  end


  def get_overdue_issues_chart(project_id,block_name)
    get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(project_id,block_name)
    get_sql_for_trackers_and_statuses_not = get_sql_for_trackers_and_statuses_not(project_id,block_name)
    stringSqlProjectsSubProjects = return_ids(project_id)
    get_sql_for_filter_query = get_sql_for_filter_query(project_id)
    Issue.find_by_sql(["select 2 as id, 'Overdue' as typeissue, count(1) as totalissuedelayed
                                                  from issues
                                                  where project_id in (#{stringSqlProjectsSubProjects})
                                                  and due_date is not null
                                                  and due_date <  '#{Date.today}' #{get_sql_for_trackers_and_statuses_not} #{get_sql_for_filter_query}

                                                  union
                                                  select 1 as id, 'Delivered' as typeissue, count(1) as totalissuedelayed
                                                  from issues
                                                  where project_id in (#{stringSqlProjectsSubProjects}) #{get_sql_for_trackers_and_statuses} #{get_sql_for_filter_query}
                                                  and due_date is not null
                                                  and due_date <= '#{Date.today}'

                                                  union
                                                  select 3 as id, 'To be delivered' as typeissue, count(1) as totalissuedelayed
                                                  from issues
                                                  where project_id in (#{stringSqlProjectsSubProjects}) #{get_sql_for_trackers_and_statuses_not} #{get_sql_for_filter_query}
                                                  and due_date is not null
                                                  and due_date >= '#{Date.today}'

                                                  order by 1;"])
  end




  def get_overdue_issues(project_id,block_name)
    get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(project_id,block_name)
    get_sql_for_trackers_and_statuses_not = get_sql_for_trackers_and_statuses_not(project_id,block_name)
    stringSqlProjectsSubProjects = return_ids(project_id)
    p get_sql_for_filter_query = get_sql_for_filter_query(project_id)
    #     Issue.find_by_sql(["select * from issues
    #                                                   where project_id in (#{stringSqlProjectsSubProjects}) #{get_sql_for_trackers_and_statuses} #{get_sql_for_filter_query}
    #                                                   and due_date is not null
    #                                                   and due_date < '#{Date.today}'
    #                                                   and status_id in (select id from issue_statuses where is_closed = ? )
    #                                                   order by due_date;",false])
    Issue.find_by_sql(["select *
                                                    from issues
                                                    where issues.project_id in (#{stringSqlProjectsSubProjects})
                                                    and issues.due_date is not null
                                                    and issues.due_date < '#{Date.today}'
#{get_sql_for_trackers_and_statuses_not} #{get_sql_for_filter_query}


                                                    order by issues.due_date;"])
  end


  def get_unmanagement_issues(project_id,block_name)
    stringSqlProjectsSubProjects = return_ids(project_id)
    get_sql_for_filter_query = get_sql_for_filter_query(project_id)
    get_sql_for_trackers_and_statuses_unmanage = get_sql_for_trackers_and_statuses_unmanage(project_id,block_name)

    Issue.find_by_sql("select *
                               from issues  where project_id in (#{stringSqlProjectsSubProjects}) #{get_sql_for_trackers_and_statuses_unmanage} #{get_sql_for_filter_query}
                               and ((due_date+0)=0 or due_date is null)
                               order by 1;")

  end

  def get_sql_for_trackers_and_statuses_unmanage(project_id,graph_type)
    sql = ""
    project_user_preference = ProjectUserPreference.where(:user_id => User.current.id,:project_id=> project_id)
    if project_user_preference.present?
      setting = project_user_preference.last.overdue_unmanage_tasks_settings.where(:name=>graph_type)

      if setting.present?
        trackers = setting.last.trackers.present? ? setting.last.trackers.join(','): ""
        statuses = setting.last.statuses.present? ? setting.last.statuses.join(',') : ""
        # get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(setting.trackers.join(","),setting.statuses.join(","))
      end
    end
    # if trackers.present?
    #    sql="and tracker_id in (#{trackers})"
    # end
    if statuses.present?
      sql = sql + "and status_id in (#{statuses.chomp(",")})"
    end

    return sql
  end

  def get_sql_for_trackers_and_statuses_not(project_id,graph_type)
    sql = ""
    project_user_preference = ProjectUserPreference.where(:user_id => User.current.id,:project_id=> project_id)
    if project_user_preference.present?
      setting = project_user_preference.last.overdue_unmanage_tasks_settings.where(:name=>graph_type)
      if setting.present?
        trackers = setting.last.trackers.present? ? setting.last.trackers.join(",") : ""
        statuses = setting.last.statuses.present? ? setting.last.statuses.join(",") : ""
        # get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(setting.trackers.join(","),setting.statuses.join(","))
      end
    end
    # if trackers.present?
    #    sql="and tracker_id in (#{trackers})"
    # end
    if statuses.present?
      sql = sql + "and status_id not in (#{statuses.chomp(",")})"
    else
      sql = sql + "and status_id not in (5)"
    end

    return sql
  end
  def get_sql_for_trackers_and_statuses(project_id,graph_type)
    sql = ""
    project_user_preference = ProjectUserPreference.where(:user_id => User.current.id,:project_id=> project_id)
    if project_user_preference.present?
      setting = project_user_preference.last.overdue_unmanage_tasks_settings.where(:name=>graph_type)
      if setting.present?
        trackers = setting.last.trackers.present? ? setting.last.trackers.join(",") : ""
        statuses = setting.last.statuses.present? ? setting.last.statuses.join(",") : ""
        # get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(setting.trackers.join(","),setting.statuses.join(","))
      end
    end
    # if trackers.present?
    #    sql="and tracker_id in (#{trackers})"
    # end
    if statuses.present?
      sql = sql + "and status_id in (#{statuses.chomp(",")})"
    else
      sql = sql + "and status_id in (5)"
    end

    return sql
  end

  def get_sql_for_only_trackers(project_id,graph_type)
    sql = ""
    project_user_preference = ProjectUserPreference.where(:user_id => User.current.id,:project_id=> project_id)
    if project_user_preference.present?
      setting = project_user_preference.last.overdue_unmanage_tasks_settings.where(:name=>graph_type)
      if setting.present?
        trackers = setting.last.trackers.present? ? setting.last.trackers.join(",") : ""
        statuses = setting.last.statuses.present? ? setting.last.statuses.join(",") : ""
        # get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(setting.trackers.join(","),setting.statuses.join(","))
      end
    end
    # if trackers.present?
    #    sql="and tracker_id in (#{trackers})"
    # end
    if trackers.present?
      sql = sql + "and tracker_id in (#{trackers.chomp(",")})"
    end

    return sql
  end
  def get_sql_for_filter_query(project_id)
    get_sql_for_filter_query = ""
    @find_dashboard_query = DashboardQuery.where(:project_id=>project_id,:user_id=>User.current.id)
    if @find_dashboard_query.present?
      get_sql_for_filter_query = @find_dashboard_query.last.statement
      if get_sql_for_filter_query.present?
        get_sql_for_filter_query = "AND " + get_sql_for_filter_query
      end
    end
    return get_sql_for_filter_query
  end

  def get_selected__trackers_and_statuses(project_id,graph_type)
    project_user_preference = ProjectUserPreference.where(:user_id => User.current.id,:project_id=> project_id)
    if project_user_preference.present?
      setting = project_user_preference.last.overdue_unmanage_tasks_settings.where(:name=>graph_type)
      if setting.present?
        @trackers = setting.last.trackers.present? ? setting.last.trackers : []
        @statuses = setting.last.statuses.present? ? setting.last.statuses : []
        # get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(setting.trackers.join(","),setting.statuses.join(","))
      end
    end
    return @trackers,@statuses

  end


  def get_selected_custom_query(project_id,graph_type)
    project_user_preference = ProjectUserPreference.where(:user_id => User.current.id,:project_id=> project_id)
    if project_user_preference.present?
      setting = project_user_preference.last.overdue_unmanage_tasks_settings.where(:name=>graph_type)
      if setting.present? && setting.last.custom_query_id.present?
          @custom_query_id = setting.last.custom_query_id.last
          @custom_query_title = setting.last.custom_query_name
           @issue_query= IssueQuery.find(@custom_query_id.to_i)
           p "++++++++++=issue_query+++++++++"
          p setting.last.custom_query_name
           p @issue_query
        p @custom_query_title
            # @issues = issue_query.issues
      # get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(setting.trackers.join(","),setting.statuses.join(","))
      end
    end
    return @custom_query_id,@issue_query,@custom_query_title

  end


  #get unmanagement issues by main project
  def retrieve_dash_board_query
      if !params[:query_id].blank?
      cond = "project_id IS NULL"
      cond << " OR project_id = #{@project.id}" if @project
      @query = DashboardQuery.where(cond).find(params[:query_id])
      raise ::Unauthorized unless @query.visible?
      @query.project = @project
      session[:query] = {:id => @query.id, :project_id => @query.project_id}
      sort_clear
    elsif api_request? || params[:set_filter] || session[:query].nil? || session[:query][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = DashboardQuery.new(:name => "_")
      @query.project = @project
      @query.build_from_params(params)
      session[:query] = {:project_id => @query.project_id, :filters => @query.filters, :group_by => @query.group_by, :column_names => @query.column_names}
    else
      # retrieve from session
      @query = nil
      @query = DashboardQuery.find_by_id(session[:query][:id]) if session[:query][:id]
      @query ||= DashboardQuery.new(:name => "_", :filters => session[:query][:filters], :group_by => session[:query][:group_by], :column_names => session[:query][:column_names])
      @query.project = @project
    end
  end

  #get overdue issues for char by by project and subprojects
def get_save_text_editor_value(project_id)
  save_text_editor_value=""
  @project_preference = ProjectUserPreference.project_user_preference(User.current.id,project_id)
  if @project_preference.present?
    save_text_editor_value = @project_preference.save_text_editor
  end
return save_text_editor_value
end


  def get_issues_burn_down(query,project)
    get_sql_for_filter_query = get_sql_for_filter_query(project.id)

    @project= project
    dash_board_query = DashboardQuery.where(:project_id=>@project.id,:user_id=>User.current.id)
    if dash_board_query.present?
      @query = dash_board_query.first
    else
      @query = query
    end
    if @query.present? && @query.filters.present? && @query.filters["fixed_version_id"].present?
      find_fixed_version_ids= @query.filters["fixed_version_id"].values.last
      find_versions = Version.where(:id=>find_fixed_version_ids)

      start_date = find_versions.sort_by(&:ir_start_date).first.ir_start_date.present? ? find_versions.sort_by(&:ir_start_date).first.ir_start_date : Date.today
      end_date = find_versions.sort_by(&:ir_end_date).last.ir_end_date.present? ? find_versions.sort_by(&:ir_end_date).last.ir_end_date : (Date.today-30)
      # start_date = find_version.ir_start_date
      # end_date = find_version.ir_end_date
      total_no_of_days = (start_date.to_date..end_date.to_date).to_a.count
      @total_dates= (start_date.to_date..end_date.to_date).to_a
      # dashboard_helper = Object.new.extend(DashboardHelper)
      # get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(@project.id,"work_burndown_chart")
      get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(@project.id,"issues_burndown_chart")
      get_sql_for_only_trackers = get_sql_for_only_trackers(@project.id,"issues_burndown_chart")

      @idle_issues_count = @project.issues.where("issues.fixed_version_id IN (#{find_versions.map(&:id).join(',')}) #{get_sql_for_filter_query} #{get_sql_for_only_trackers}").count
      @idle_issues_total_count = @idle_issues_count
      # idle_issues_devide = (@idle_issues_count.to_f/(total_no_of_days.to_f-1.0))

      if @idle_issues_count.to_i > total_no_of_days.to_i
        difference = @idle_issues_count-total_no_of_days
        idle_issues_devide = (@idle_issues_count.to_f/total_no_of_days.to_f)
        idle_issues_devide1 = (idle_issues_devide/total_no_of_days)
        idle_issues_devide = idle_issues_devide+idle_issues_devide1
       #idle_issues_devide = (@idle_issues_hours_count.to_f/total_no_of_days.to_f-1)
      else
        idle_issues_devide = @idle_issues_count > 0 ? (@idle_issues_count.to_f/(total_no_of_days.to_f-1.0)) : 0.0
      end

      @idle_issues_count_array=[]
      @issues_count_array=[]
      (start_date.to_date..end_date.to_date).to_a.each_with_index do |each_day,index|
        if index.to_i ==0
          @idle_issues_count_array << @idle_issues_count
        else
          @idle_issues_count_array << (@idle_issues_count -= idle_issues_devide).round
        end

        closed_status = IssueStatus.find_by_name("Closed")
        closed_issues = @project.issues.where("fixed_version_id in (#{find_versions.map(&:id).join(',')}) #{get_sql_for_filter_query} #{get_sql_for_only_trackers}").where("closed_on <= ? AND status_id=?",(each_day.to_date),closed_status.id).count

        # @idle_issues_total_count
        issues_count = (@idle_issues_total_count.to_f-closed_issues.to_f)
        @issues_count_array << issues_count rescue 0
      end
    else
      total_no_of_days= 30
      start_date = (Date.today-total_no_of_days)
      end_date = Date.today
      @total_dates= ((Date.today-30)..Date.today).to_a
      @idle_issues_count = @project.issues.where("issues.created_on between '#{start_date}' and '#{end_date}'").count
      @idle_issues_total_count = @idle_issues_count
      idle_issues_devide = (@idle_issues_count.to_f/total_no_of_days.to_f)
      @idle_issues_count_array=[]
      @issues_count_array=[]
      (start_date.to_date..end_date.to_date).to_a.each_with_index do |each_day,index|
        if index.to_i ==0
          @idle_issues_count_array << @idle_issues_count
        else
          @idle_issues_count_array << (@idle_issues_count -= idle_issues_devide).round
        end

        closed_issues = @project.issues.where("issues.created_on between '#{start_date}' and '#{end_date}'").where("issues.closed_on <= ?",Time.parse(each_day.to_date.to_s)).count
        # @idle_issues_total_count
        issues_count = @idle_issues_total_count > 0 ? (@idle_issues_total_count.to_i-closed_issues.to_i) : 0.0
        @issues_count_array << issues_count rescue 0
      end
    end
    return @total_dates,@idle_issues_count_array,@issues_count_array
  end


  def get_work_burn_down(query,project)

     get_sql_for_filter_query = get_sql_for_filter_query(project.id)
    @project= project
     dash_board_query = DashboardQuery.where(:project_id=>@project.id,:user_id=>User.current.id)
    if dash_board_query.present?
      @query = dash_board_query.first
    else
      @query = query
    end

    if @query.present? && @query.filters.present? && @query.filters["fixed_version_id"].present?
      find_fixed_version_ids= @query.filters["fixed_version_id"].values.last
      find_versions = Version.where(:id=>find_fixed_version_ids)
      # start_date = find_versions.sort_by(&:ir_start_date).first.ir_start_date rescue Date.today
      # end_date = find_versions.sort_by(&:ir_end_date).last.ir_end_date rescue Date.today-30
      start_date = find_versions.sort_by(&:ir_start_date).first.ir_start_date.present? ? find_versions.sort_by(&:ir_start_date).first.ir_start_date : (Date.today-30)
      end_date = find_versions.sort_by(&:ir_end_date).last.ir_end_date.present? ? find_versions.sort_by(&:ir_end_date).last.ir_end_date : Date.today

      # start_date = find_version.ir_start_date
      # end_date = find_version.ir_end_date
      total_no_of_days = (start_date.to_date..end_date.to_date).to_a.count
      @total_dates= (start_date.to_date..end_date.to_date).to_a

      # dashboard_helper = Object.new.extend(DashboardHelper)
      # get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(@project.id,"work_burndown_chart")
      get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(@project.id,"work_burndown_chart")
      get_sql_for_only_trackers = get_sql_for_only_trackers(@project.id,"work_burndown_chart")

      @idle_issues = @project.issues.where("issues.fixed_version_id IN
 (#{find_versions.map(&:id).join(',')}) #{get_sql_for_filter_query} #{get_sql_for_only_trackers}")
      if @idle_issues.present?
       @idle_issues_hours_count =@idle_issues.map(&:estimated_hours).compact.sum
       @total_estimation_hours = @idle_issues.map(&:estimated_hours).compact.sum
       @total_spent_hours = TimeEntry.where(:spent_on=> @total_dates,:issue_id=>@idle_issues.map(&:id)).map(&:hours).compact.sum
     else
        @idle_issues_hours_count =0
      end
      @idle_issues_total_count = @idle_issues_hours_count
      if @idle_issues_hours_count.to_i > total_no_of_days.to_i
        idle_issues_devide = (@idle_issues_hours_count.to_f/total_no_of_days.to_f)
        idle_issues_second_devide = (idle_issues_devide/total_no_of_days)
        idle_issues_actual_devide = idle_issues_devide+idle_issues_second_devide
        #idle_issues_devide = (@idle_issues_hours_count.to_f/total_no_of_days.to_f-1)
      else
        idle_issues_actual_devide = @idle_issues_hours_count > 0 ? (@idle_issues_hours_count.to_f/total_no_of_days.to_f-1) : 0.0
      end

      @idle_issues_hours_count_array=[]
      @issues_hours_count_array=[]
      (start_date.to_date..end_date.to_date).to_a.each_with_index do |each_day,index|
        if index.to_i ==0
          @idle_issues_hours_count_array << @idle_issues_hours_count
        else
          @idle_issues_hours_count_array << (@idle_issues_hours_count -= idle_issues_actual_devide).round
        end
        sprint_issues = @project.issues.where("fixed_version_id IN (#{find_versions.map(&:id).join(',') }) #{get_sql_for_filter_query} #{get_sql_for_only_trackers}")
        if sprint_issues.present?
          # closed_issues = closed_issu.map(&:hours).compact.sum
          time_entries = TimeEntry.where(:spent_on=> start_date.to_date..each_day.to_date,:issue_id=>sprint_issues.map(&:id)).map(&:hours).compact.sum
        else
          time_entries=0
        end
        issues_count = @idle_issues_total_count > 0 ? (@idle_issues_total_count.to_f-time_entries.to_f) : 0.0
        @issues_hours_count_array << issues_count rescue 0

      end
    else
      total_no_of_days= 30
      start_date = (Date.today-total_no_of_days)
      end_date = Date.today
      @total_dates= ((Date.today-30)..Date.today).to_a
      @idle_issues_hours_count = @project.issues.where("issues.created_on between '#{start_date}' and '#{end_date}'").count
      @idle_issues_total_count = @idle_issues_hours_count
      idle_issues_devide = (@idle_issues_hours_count.to_f/total_no_of_days.to_f)
      @idle_issues_hours_count_array=[]
      @issues_hours_count_array=[]
      (start_date.to_date..end_date.to_date).to_a.each_with_index do |each_day,index|
        if index.to_i ==0
          @idle_issues_hours_count_array << @idle_issues_hours_count
        else
          @idle_issues_hours_count_array << (@idle_issues_hours_count -= idle_issues_devide).round
        end
        closed_issues = @project.issues.where("issues.created_on between '#{start_date}' and '#{end_date}'")
        # @idle_issues_total_count

        # sprint_issues = @project.issues.where("fixed_version_id IN (#{find_versions.map(&:id).join(',') })")
        if closed_issues.present?
          # closed_issues = closed_issu.map(&:hours).compact.sum
          time_entries = TimeEntry.where(:spent_on=> start_date.to_date..each_day.to_date,:issue_id=>closed_issues.map(&:id)).map(&:hours).compact.sum
        else
          time_entries=0
        end
        issues_count = @idle_issues_total_count > 0 ? (@idle_issues_total_count.to_f-time_entries.to_f) : 0.0
        @issues_hours_count_array << issues_count rescue 0

      end
    end
    return @total_dates,@idle_issues_hours_count_array,@issues_hours_count_array,@total_estimation_hours,@total_spent_hours
  end




  def get_story_burn_down(query,project)
    get_sql_for_filter_query = get_sql_for_filter_query(project.id)

    @project= project
    dash_board_query = DashboardQuery.where(:project_id=>@project.id,:user_id=>User.current.id)
    if dash_board_query.present?
      @query = dash_board_query.first
    else
      @query = query
    end
    if @query.present? && @query.filters.present? && @query.filters["fixed_version_id"].present?
      find_fixed_version_ids= @query.filters["fixed_version_id"].values.last
      find_versions = Version.where(:id=>find_fixed_version_ids)
      # start_date = find_versions.sort_by(&:ir_start_date).first.ir_start_date rescue Date.today
      # end_date = find_versions.sort_by(&:ir_end_date).last.ir_end_date rescue Date.today-30
      start_date = find_versions.sort_by(&:ir_start_date).first.ir_start_date.present? ? find_versions.sort_by(&:ir_start_date).first.ir_start_date : (Date.today-30)
      end_date = find_versions.sort_by(&:ir_end_date).last.ir_end_date.present? ? find_versions.sort_by(&:ir_end_date).last.ir_end_date : Date.today

      # start_date = find_version.ir_start_date
      # end_date = find_version.ir_end_date
      total_no_of_days = (start_date.to_date..end_date.to_date).to_a.count
      @total_dates= (start_date.to_date..end_date.to_date).to_a
      # dashboard_helper = Object.new.extend(DashboardHelper)
      # get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(@project.id,"work_burndown_chart")
      get_sql_for_trackers_and_statuses = get_sql_for_trackers_and_statuses(@project.id,"story_burndown_chart")
      get_sql_for_only_trackers = get_sql_for_only_trackers(@project.id,"story_burndown_chart")
      story = CustomField.find_by_name('Story Point')
      # @idle_issues_count = @project.issues.where("issues.fixed_version_id IN (#{find_versions.map(&:id).join(',')}) #{get_sql_for_filter_query} #{get_sql_for_only_trackers}").count

      @idle_issues_count = Issue.find_by_sql("select * from issues INNER JOIN custom_values on issues.id=custom_values.customized_id WHERE custom_values.custom_field_id=#{story.id} and issues.fixed_version_id IN (#{find_versions.map(&:id).join(',')}) #{get_sql_for_filter_query} #{get_sql_for_only_trackers}").compact.map(&:value).map(&:to_i).sum


      @idle_issues_total_count = @idle_issues_count
      # idle_issues_devide = (@idle_issues_count.to_f/(total_no_of_days.to_f-1.0))


      if @idle_issues_count.to_i > total_no_of_days.to_i
        difference = @idle_issues_count-total_no_of_days
        idle_issues_devide = (@idle_issues_count.to_f/total_no_of_days.to_f)
        idle_issues_devide1 = (idle_issues_devide/total_no_of_days)
        idle_issues_devide = idle_issues_devide+idle_issues_devide1
        #idle_issues_devide = (@idle_issues_hours_count.to_f/total_no_of_days.to_f-1)
      else
        idle_issues_devide = @idle_issues_count > 0 ? (@idle_issues_count.to_f/(total_no_of_days.to_f-1.0)) : 0.0
      end

      @idle_issues_count_array=[]
      @issues_count_array=[]
      (start_date.to_date..end_date.to_date).to_a.each_with_index do |each_day,index|
        if index.to_i ==0
          @idle_issues_count_array << @idle_issues_count
        else
          @idle_issues_count_array << (@idle_issues_count -= idle_issues_devide).round
        end

        closed_status = IssueStatus.find_by_name("Closed")
        # closed_issues = @project.issues.where("fixed_version_id in (#{find_versions.map(&:id).join(',')}) #{get_sql_for_trackers_and_statuses}").where("closed_on <= ? AND status_id=?",(each_day.to_date),closed_status.id).count

        closed_issues = Issue.find_by_sql("select * from issues INNER JOIN custom_values on issues.id=custom_values.customized_id WHERE custom_values.custom_field_id=#{story.id} and issues.closed_on <='#{each_day.to_date}' and issues.fixed_version_id IN (#{find_versions.map(&:id).join(',')}) and issues.status_id=#{closed_status.id} #{get_sql_for_filter_query} #{get_sql_for_only_trackers}").compact.map(&:value).map(&:to_i).sum
        # @idle_issues_total_count
        issues_count = @idle_issues_total_count > 0 ? (@idle_issues_total_count.to_f-closed_issues.to_f) : 0.0
        @issues_count_array << issues_count rescue 0
      end
    else
      story = CustomField.find_by_name('Story Point')
      closed_status = IssueStatus.find_by_name("Closed")
      total_no_of_days= 30
      start_date = (Date.today-total_no_of_days)
      end_date = Date.today
      @total_dates= ((Date.today-30)..Date.today).to_a
      # @idle_issues_count = @project.issues.where("issues.created_on between '#{start_date}' and '#{end_date}'").count
      @idle_issues_count = Issue.find_by_sql("select * from issues INNER JOIN custom_values on issues.id=custom_values.customized_id WHERE custom_values.custom_field_id=#{story.id} and issues.created_on between '#{start_date}' and '#{end_date}' and project_id=#{@project.id} #{get_sql_for_filter_query} #{get_sql_for_only_trackers}").compact.map(&:value).map(&:to_i).sum

      @idle_issues_total_count = @idle_issues_count
      idle_issues_devide = (@idle_issues_count.to_f/total_no_of_days.to_f)
      @idle_issues_count_array=[]
      @issues_count_array=[]
      (start_date.to_date..end_date.to_date).to_a.each_with_index do |each_day,index|
        if index.to_i ==0
          @idle_issues_count_array << @idle_issues_count
        else
          @idle_issues_count_array << (@idle_issues_count -= idle_issues_devide).round
        end

        # closed_issues = @project.issues.where("issues.created_on between '#{start_date}' and '#{end_date}'").where("issues.closed_on <= ?",Time.parse(each_day.to_date.to_s)).count
        # @idle_issues_total_count
        closed_issues = Issue.find_by_sql("select * from issues INNER JOIN custom_values on issues.id=custom_values.customized_id WHERE custom_values.custom_field_id=#{story.id} and issues.created_on between '#{start_date}' and '#{end_date}' and issues.closed_on <='#{each_day.to_date}' and issues.project_id=#{@project.id} and issues.status_id=#{closed_status.id} #{get_sql_for_filter_query} #{get_sql_for_only_trackers}").compact.map(&:value).map(&:to_i).sum

        issues_count = (@idle_issues_total_count.to_i-closed_issues.to_i)
        @issues_count_array << issues_count rescue 0
      end
    end
    return @total_dates,@idle_issues_count_array,@issues_count_array
  end


  def get_resource_allocation(project,query)
    sprint_id=''
    start_date=''
    end_date=''

    if query.filters["fixed_version_id"].present?
       sprint_id = query.filters["fixed_version_id"][:values].last
       find_sprint = Version.find(sprint_id)
       start_date = find_sprint.ir_start_date
       end_date = find_sprint.ir_end_date
    end

   #   find_sql='select id,client_name,project_name,offshore_count,onsite_count,billable_working_hours,(billable_working_hours-pto_hours) as
# available_hours,allocated_hours from ((
# select x.id,x.client_name,x.project_name,x.offshore offshore_count,x.onsite as onsite_count,
# IFNULL(cv.value,0) productive_hours,IFNULL((cv.value*offshore*(select count(*) from (
#  (select (CASE weekday(selected_date) WHEN 5 THEN NULL
#           WHEN 6 THEN NULL ELSE selected_date END) as selected_date  from 
#  (select adddate(''1970-01-01'',t4.i*10000 + t3.i*1000 + t2.i*100 + t1.i*10 + t0.i) selected_date from
#   (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t0,
#   (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t1,
#   (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t2,
#   (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t3,
#   (select 0 i union select 1 union select 2 union select 3 union select 4 union select 5 union select 6 union select 7 union select 8 union select 9) t4) v
#  where selected_date between ''2016-04-20'' and ''2016-04-28''  ) ) as a where   IFNULL(a.selected_date,''AA'') <> ''AA''  
# and a.selected_date 
# NOT IN (select date as selected_date  from public_holydays where selected_date between ''2016-04-20'' and ''2016-04-28''  )
# )) 
# ,0) as billable_working_hours,
# IFNULL((select sum(i1.estimated_hours) from issues i1 
# inner join time_entries te1 on te1.project_id=i1.project_id  
# where i1.project_id=x.id and i1.created_on BETWEEN ''2016-04-20'' AND ''2016-04-28'' and te1.activity_id in (SELECT id  FROM enumerations WHERE enumerations.type IN (''TimeEntryActivity'') 
# and name !=''PTO'')  
# ),0) as allocated_hours,
# IFNULL((select sum(te1.hours) from time_entries te1  
# where te1.project_id=x.id   and te1.spent_on BETWEEN ''2016-04-20'' AND ''2016-04-28'' and te1.activity_id in (SELECT id  FROM enumerations WHERE enumerations.type IN (''TimeEntryActivity'') 
# and name = ''PTO'')  
# ),0) as pto_hours,
# v.id as version_id
#  from (
# (select p.id,p.name as project_name,cp.name as client_name,SUM(if(uo.location_type="offshore" && m.capacity >0,1,0)) as offshore,
# SUM(if(uo.location_type="onsite" && m.capacity >0,1,0)) as onsite from projects p
# join members m on m.project_id=p.id
# join users u on u.id=m.user_id
# join user_official_infos uo on uo.user_id=u.id 
# join projects cp on (cp.lft < p.lft and p.rgt < cp.rgt) 
# where p.status=1 and cp.parent_id is null and p.parent_id is not null group by p.id order by cp.name) as x
# ) 
# INNER JOIN  custom_values cv on cv.customized_id=x.id and cv.customized_type=''project''
# INNER JOIN  custom_fields cf on cv.custom_field_id=cf.id and cf.type=''ProjectCustomField'' and cf.name =''ProductiveHours''
# left join versions v on v.project_id = x.id where x.id is not null ) as y )
# group by id'

# result = User.find_by_sql("call getAllocationUsersReports('','','','')")
# ActiveRecord::Base.connection.execute("call getAllocationUsersReports('','','','')")
#  sql="call getAllocationUsersReports('','#{sprint_id}','#{start_date}','#{end_date}')"
    sql="call getAllocationUsersReports('#{find_sprint.project_id rescue 1}','#{sprint_id}','#{start_date}','#{end_date}')"

 # sql="call getAllocationUsersReports('181','2056','2016-02-17','2016-03-01')"
   connection = ActiveRecord::Base.connection
      begin
       result = connection.select_all(sql)
      rescue NoMethodError
      ensure
        connection.reconnect! unless connection.active?
      end

    p "++++++++result++++++++++++"
    p result
    p "==============end +++++++++"
   return result

  end

  def get_closed_sprints(project)
    if project.present? && project.versions.present?
    project.versions.where(:status=>'closed').map(&:id)

    end
  end



end
