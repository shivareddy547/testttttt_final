class DashboardController < ApplicationController
  helper :issues
  helper :users
  helper :custom_fields
  helper :dashboard
  helper :journals
  helper :projects
  include ProjectsHelper
  helper :custom_fields
  include CustomFieldsHelper
  helper :issue_relations
  include IssueRelationsHelper
  helper :watchers
  include WatchersHelper
  helper :attachments
  include AttachmentsHelper
  helper :queries
  include QueriesHelper
  helper :repositories
  include RepositoriesHelper
  helper :sort
  include SortHelper
  include IssuesHelper
  helper :timelog
  include Redmine::Export::PDF

  BLOCKS = { 'issuesassignedtome' => :label_assigned_to_me_issues,
             'issuesreportedbyme' => :label_reported_issues,
             'issueswatched' => :label_watched_issues,
             'news' => :label_news_latest,
             'calendar' => :label_calendar,
             'documents' => :label_document_plural,
             'timelog' => :label_spent_time,
             'overduetasks' => :label_overdue_tasks,
             'unmanageabletasks' => :label_unmanageable_tasks,
             'issues_burndown_chart' => :label_issues_burndown_chart,
             'work_burndown_chart' => :label_work_burndown_chart,
             'story_burndown_chart' => :label_story_burndown_chart,
             'texteditor' => :label_texteditor
  }.freeze

  # BLOCKS = { 'issuesassignedtome' => :label_assigned_to_me_issues,
  #            'issuesreportedbyme' => :label_reported_issues,
  #            'issueswatched' => :label_watched_issues,
  #            'news' => :label_news_latest,
  #            'calendar' => :label_calendar,
  #            'documents' => :label_document_plural,
  #            'timelog' => :label_spent_time,
  #            'overduetasks' => :label_overdue_tasks,
  #            'unmanageabletasks' => :label_unmanageable_tasks
  # }.merge(Redmine::Views::MyPage::Block.additional_blocks).freeze

  DEFAULT_LAYOUT = {  'left' => ['issuesassignedtome'],
                      'right' => ['issuesreportedbyme']
  }.freeze

  def index


  end
  def page
    @user = User.current
    @blocks = @user.pref[:my_page_layout] || DEFAULT_LAYOUT
  end

  def page_layout
   # tool = McTools.new
   #get main project
    # @project = Project.find_by_identifier(params[:id])
    @project= Project.find(params[:project_id])

    retrieve_query

    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)

    sort_update(@query.sortable_columns)

    @query.sort_criteria = sort_criteria.to_a
    if @query.present? && @query.filters.present? && @query.filters["fixed_version_id"].present?
      find_fixed_version_id= @query.filters["fixed_version_id"].values.last.first
      find_version = Version.find(find_fixed_version_id)
      start_date = find_version.ir_start_date
      end_date = find_version.ir_end_date
      total_no_of_days = (start_date.to_date..end_date.to_date).to_a.count
      @total_dates= (start_date.to_date..end_date.to_date).to_a
      @idle_issues_count = @project.issues.where("issues.fixed_version_id IN (#{find_version.id})").count
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

        # p "issues.status_id IN (SELECT id FROM issue_statuses WHERE is_closed=0) AND issues.tracker_id IN ('1') AND issues.created_on > '#{each_day}'"
        # issues_count = @project.issues.open.where("issues.status_id IN (SELECT id FROM issue_statuses WHERE is_closed=0) AND issues.fixed_version_id IN (#{find_version.id})").count
        # p date_obj = Time.parse(each_day.to_date.to_s)
        closed_issues = @project.issues.where("issues.closed_on <= ? AND issues.fixed_version_id= ?",Time.parse(each_day.to_date.to_s) , find_version.id).count
        # @idle_issues_total_count
        issues_count = (@idle_issues_total_count.to_i-closed_issues.to_i)
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
        # p "issues.status_id IN (SELECT id FROM issue_statuses WHERE is_closed=0) AND issues.tracker_id IN ('1') AND issues.created_on > '#{each_day}'"
        # issues_count = @project.issues.open.where("issues.status_id IN (SELECT id FROM issue_statuses WHERE is_closed=0) AND issues.fixed_version_id IN (#{find_version.id})").count
        # p date_obj = Time.parse(each_day.to_date.to_s)
        closed_issues = @project.issues.where("issues.created_on between '#{start_date}' and '#{end_date}'").where("issues.closed_on <= ?",Time.parse(each_day.to_date.to_s)).count
        # @idle_issues_total_count
        issues_count = (@idle_issues_total_count.to_i-closed_issues.to_i)
        @issues_count_array << issues_count rescue 0
      end
    end

    if @query.valid?
      case params[:format]
        when 'csv', 'pdf'
          @limit = Setting.issues_export_limit.to_i
          if params[:columns] == 'all'
            @query.column_names = @query.available_inline_columns.map(&:name)
          end
        when 'atom'
          @limit = Setting.feeds_limit.to_i
        when 'xml', 'json'
          @offset, @limit = api_offset_and_limit
          @query.column_names = %w(author)
        else
          @limit = per_page_option
      end

      @issue_count = @query.issue_count

    end

    @project= Project.find(params[:project_id])
    @user = User.current
    @project_preference = ProjectUserPreference.project_user_preference(User.current.id,@project.id)
    @blocks = @project_preference[:my_page_layout] || DEFAULT_LAYOUT
    # @blocks = @user.pref[:my_page_layout] || DEFAULT_LAYOUT.dup
    @block_options = []

    BLOCKS.each do |k, v|
        unless @blocks.values.flatten.include?(k)
        @block_options << [l("my.blocks.#{v}", :default => [v, v.to_s.humanize]), k.dasherize]
      end
    end
  end

  def add_block
    @project=Project.find(params[:project_id])
    block = params[:block].to_s.underscore
    if block.present? && BLOCKS.key?(block)
      @project_preference = ProjectUserPreference.project_user_preference(User.current.id,@project.id)
      layout = @project_preference[:my_page_layout] || {}
      # remove if already present in a group
      %w(top left right).each {|f| (layout[f] ||= []).delete block }
      layout['top'].unshift block
      @project_preference.others={:my_page_layout=> layout}
      @project_preference.save
    end
    redirect_to dashboard_page_layout_path(:project_id=>@project.id)
  end

  def remove_block
    @project=Project.find(params[:project_id])
    block = params[:block].to_s.underscore
    @user = User.current
    # remove block in all groups
    if block.present? && BLOCKS.key?(block)
      @project_preference = ProjectUserPreference.project_user_preference(User.current.id,@project.id)
      layout = @project_preference[:my_page_layout] || {}
      # remove if already present in a group
      %w(top left right).each {|f| (layout[f] ||= []).delete block }
      @project_preference.others={:my_page_layout=> layout}
      @project_preference.save
    end
    redirect_to dashboard_page_layout_path(:project_id=>@project.id)

  end
  def order_blocks
    @project=Project.find(params[:project_id])
    @project_preference = ProjectUserPreference.project_user_preference(User.current.id,@project.id)
    group = params[:group]
    @user = User.current
    if group.is_a?(String)
      group_items = (params["blocks"] || []).collect(&:underscore)
      group_items.each {|s| s.sub!(/^block_/, '')}
      if group_items and group_items.is_a? Array
        # layout = @user.pref[:my_page_layout] || {}
        layout = @project_preference[:my_page_layout] || {}
        # remove group blocks if they are presents in other groups
        %w(top left right).each {|f|
          layout[f] = (layout[f] || []) - group_items
        }
        layout[group] = group_items
        @project_preference.others={:my_page_layout=> layout}
        @project_preference.save
      end
    end
    render :nothing => true
  end
  def graphs_settings
    @project=Project.find(params[:project_id])
    project_preference = OverdueUnmanageTasksSetting.project_user_preference_settings(User.current.id,@project.id,params[:block_id],params[:tracker_id],params[:status_id])
    project_preference.trackers = params[:tracker_id]
    project_preference.statuses =   params[:status_id]

    project_preference.save
    redirect_to dashboard_page_layout_path(:project_id=>@project.id)
    # render "projects/show"
  end

  def filter_query
  @project=Project.find(params[:project_id])
  dashboard_query = DashboardQuery.project_user_filter_init(User.current.id,@project.id)
  dashboard_query.build_from_params(params)

  dashboard_query.save
  redirect_to project_path(:id=>@project.id)

  end
  def save_text_editor
    @project=Project.find(params[:project_id])
    @project_preference = ProjectUserPreference.project_user_preference(User.current.id,@project.id)
   # dashboard_query = DashboardQuery.project_user_filter_init(User.current.id,@project.id)
    @project_preference.save_text_editor = params[:text_editor_block]
    @project_preference.save
    @project_preference.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
    @project_preference.save
    redirect_to project_path(:id=>@project.id)
  end
  def preview_text_editor

    @project=Project.find(params[:project_id])
    @project_preference = ProjectUserPreference.project_user_preference(User.current.id,@project.id)
    @description = (params[:text_editor_block] ? params[:text_editor_block] : "He llo guys")
    render :layout => false
  end
end
