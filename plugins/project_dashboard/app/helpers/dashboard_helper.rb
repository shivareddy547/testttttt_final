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
                                                from issues  where project_id in (#{stringSqlProjectsSubProjects})  #{get_sql_for_trackers_and_statuses_unmanage} #{get_sql_for_filter_query} and due_date is not null
                                                union
                                                select 2 as id, 'Unmanageable(s)' as typemanagement, count(1) as totalissues
                                                from issues  where project_id in (#{stringSqlProjectsSubProjects})  #{get_sql_for_trackers_and_statuses_unmanage} and due_date is null  #{get_sql_for_filter_query};")

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
                               and due_date is null
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
      sql = sql + "and status_id in (#{statuses})"
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
      sql = sql + "and status_id not in (#{statuses})"
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
      sql = sql + "and status_id in (#{statuses})"
    else
      sql = sql + "and status_id in (5)"
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





end
