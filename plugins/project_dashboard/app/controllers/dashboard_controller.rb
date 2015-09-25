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
      # @issue_pages = Paginator.new @issue_count, @limit, params['page']
      # @offset ||= @issue_pages.offset
      # # p "+++++++++@issues = @query.issues++++++++++++"
      # # p @issues = @query.issues
      # # p "+++++++++++end +++++++++="
      # @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
      #                         :order => sort_clause,
      #                         :offset => @offset,
      #                         :limit => @limit)
      # # p "+++++++++=@issues+++++++++++"
      # # p @issues
      # # p "++++++++++end ++++"
      # @issue_count_by_group = @query.issue_count_by_group


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
    # @issue = @project.issues.last
    # if @issue
    #   @description = params[:issue] && params[:issue][:description]
    #   if @description && @description.gsub(/(\r?\n|\n\r?)/, "\n") == @issue.description.to_s.gsub(/(\r?\n|\n\r?)/, "\n")
    #     @description = nil
    #   end
    #   # params[:notes] is useful for preview of notes in issue history
    #   @notes = params[:notes] || (params[:issue] ? params[:issue][:notes] : nil)
    # else
    #   @description = (params[:issue] ? params[:issue][:description] : nil)
    # end
    @project=Project.find(params[:project_id])
    @project_preference = ProjectUserPreference.project_user_preference(User.current.id,@project.id)
    @description = (params[:text_editor_block] ? params[:text_editor_block] : "He llo guys")
    render :layout => false
  end
end
