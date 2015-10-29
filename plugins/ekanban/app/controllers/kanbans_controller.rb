
class KanbansController < ApplicationController
  unloadable

  helper :issues
  helper :users
  helper :custom_fields
  helper :kanbans
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


  PROJECT_VIEW = 0  #Show selected Kanban in Project view
  GROUP_VIEW = 1    #Show selected Kanban in Group view
  MEMBER_VIEW = 2   #Show selected Kanban in Member view

  menu_item :Kanban

  skip_before_filter :check_if_login_required
  skip_before_filter :verify_authenticity_token
  before_filter :find_project, :only => [ :update_form]
  before_filter :build_new_issue_from_params, :only => [:update_form]


  def index
    @project = Project.find(params[:project_id])#Get member name of this project
    @members= @project.members
    @principals = @project.principals
    @user = User.current
    @versions = @project.versions

    @roles = @user.roles_for_project(@project)

    @member = nil
    @principal = nil

    @issue_statuss = IssueStatus.all
    @kanban_states = KanbanState.all
    @issue_status_kanban_state = IssueStatusKanbanState.all
    @kanban_flows = KanbanWorkflow.all

    params[:kanban_id] = 0 if params[:kanban_id].nil?
    params[:member_id] = 0 if params[:member_id].nil?
    params[:principal_id] = 0 if params[:principal_id].nil?

    @kanbans = []

    if params[:kanban_id].to_i > 0
      @kanbans << Kanban.find(params[:kanban_id])
    else
      @kanbans = Kanban.by_project(@project).where("is_valid = ?",true)
    end

    if params[:member_id].to_i == 0 and params[:principal_id].to_i == 0
      @view = PROJECT_VIEW
    elsif params[:member_id].to_i > 0
      @view = MEMBER_VIEW
      @member = Member.find(params[:member_id])
    else
      @view = GROUP_VIEW
      @principal = Principal.find(params[:principal_id])
    end

    #@project= Project.find(params[:id])
    retrieve_dash_board_query
    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a

   kanbans = @project.kanban

    if kanbans.present?
      kanbans.each do |each_kanban|
      @kanban = each_kanban
      if @kanban.is_valid == true
      if @project.issues.present?
        @kanban.kanban_pane.each do |each_pane|
          #issues = @project.issues.where(:status_id=>each_pane.kanban_state.issue_status.last.id) if each_pane.kanban_state.issue_status.present?
          issues = @project.issues.where(:status_id=>each_pane.kanban_state.issue_status.map(&:id),:tracker_id=>@kanban.tracker_id) if each_pane.kanban_state.issue_status.present?
          if issues.present?
            issues.each do |each_issue|
              kanban_new = KanbanCard.find_or_initialize_by_issue_id_and_kanban_pane_id(each_issue.id,each_pane.id)
              kanban_new.issue_id = each_issue.id
              kanban_new.developer_id= each_issue.assigned_to_id
              kanban_new.verifier_id=each_issue.assigned_to_id
              kanban_new.kanban_pane_id=each_pane.id
              kanban_new.save
            end
          end
        end
      end
      if @kanban.subproject_enable == true
          @kanban.kanban_pane.each do |each_pane|
          @subprojects = @project.descendants.active
          @subprojects_ids = @subprojects.map(&:id).join(',') if @subprojects.present?
          issues=[]
          if each_pane.kanban_state.present? && each_pane.kanban_state.issue_status.present? && each_pane.kanban_state.issue_status.last.id.present? && @subprojects_ids.present?
            issues = Issue.find_by_sql("select * from issues where project_id in (#{@subprojects_ids}) and status_id in (#{each_pane.kanban_state.issue_status.map(&:id).join(',')}) and tracker_id in (#{@kanban.tracker_id});");
          end
             if issues.present?
            issues.each do |each_issue|
              # kanban_new = KanbanCard.find_or_initialize_by_issue_id_and_kanban_pane_id(each_issue.id,each_pane.id)
              kanban_new = KanbanCard.where(:issue_id=>each_issue.id,:kanban_pane_id=>each_pane.id).first_or_initialize
              kanban_new.issue_id = each_issue.id
              kanban_new.developer_id= each_issue.assigned_to_id
              kanban_new.verifier_id=each_issue.assigned_to_id
              kanban_new.kanban_pane_id=each_pane.id
              kanban_new.save
            end
          end
        end
      end

      end
    end
end
    #Get all kanbans's name
    @kanban_names = @kanbans.collect{|k| k.name}

    with_format :html do
      # render :partial => "kanban_board", :collection => @kanbans, :as => :kanban
      @html_content = render_to_string :partial => "kanban_board", :collection => @kanbans, :as => :kanban
    end
    respond_to do |format|
      format.html
      # format.js { render :partial => "index", :locals => {:view=>@view, :kanbans=>@Kanbans}}
      # format.json { render :json => {:kanbans => @kanbans,
      #                                :teams => @principal,
      #                                :member => @member,
      #                                :view => @view}}
      format.js {
        render :json => { :attachmentPartial => @html_content,:sprint_id=>"test" }
      }
    end
  end



  def retrieve_dash_board_query
    @find_dashboard_query = EkanbanQuery.where(:project_id=>@project.id,:user_id=>User.current.id)
    # @query=nil
    if @find_dashboard_query.present?
      if api_request? || params[:set_filter]
        @init_filters={ 'status_id' => {:operator => "o", :values => [""]} }
        @find_dashboard_query.last.update_attributes(:filters=> @init_filters)
      end
      @query = @find_dashboard_query.last
    else
      @init_filters={ 'status_id' => {:operator => "o", :values => [""]} }
      @query ||= EkanbanQuery.new(:name => "_", :filters => @init_filters)
      @query.user_id=User.current.id
      @query.project_id= @project.id
    end

  end


  def filter_query
    @project=Project.find(params[:project_id])
    dashboard_query = EkanbanQuery.project_user_filter_init(User.current.id,@project.id)
    dashboard_query.build_from_params(params)
    dashboard_query.save
    redirect_to project_kanbans_path(:project_id=>@project.id)

  end

  def panes(kanban)
    #Get all kanban stage/state/
    panes = [] if kanban.nil? or !kanban.is_a?(Kanban)
  	panes = kanban.kanban_pane
  end


  def panes_num(kanban)
    panes(kanban).size
  end

  def cards(pane_id,project)
    cards=[]

    pane = KanbanPane.find(pane_id)
    # @kanban = pane.kanban
    if !@member.nil?
       cards = KanbanCard.by_member(@member).joins(:priority).find(:all, :conditions => ["kanban_pane_id = ?",pane.id], :order => "#{Enumeration.table_name}.position ASC")
    elsif !@principal.nil?
        cards = KanbanCard.by_group(@principal).joins(:priority).find(:all, :conditions => ["kanban_pane_id = ?",pane.id], :order => "#{Enumeration.table_name}.position ASC")
    else
      # kanban_query_statement=""
      kanban_query = EkanbanQuery.where(:project_id=>project,:user_id=>User.current.id)
      kanban_query = kanban_query.last if kanban_query.present?
      kanban_query_statement = kanban_query.statement if kanban_query.present?
      if kanban_query_statement.present?
        # kanban_query_statement = "and" + "#{kanban_query_statement}"
        kanban_query_statement = "and #{kanban_query_statement}"

      end
      cards = KanbanCard.find_by_sql("SELECT kanban_cards.* FROM kanban_cards INNER JOIN issues ON issues.id = kanban_cards.issue_id INNER JOIN enumerations ON enumerations.id = issues.priority_id AND enumerations.type IN ('IssuePriority') where kanban_pane_id=#{pane.id}  #{kanban_query_statement} order by enumerations.position ASC ")
       # cards = KanbanCard.joins(:priority).find(:all, :conditions => ["kanban_pane_id = ?",pane.id], :order => "#{Enumeration.table_name}.position ASC")
    end

    cards = cards.uniq
  end

  def assignee_name(assignee)
    assignee.is_a?(Principal)? assignee.alias : "unassigned"
  end

  def stages_and_panes(panes)
    return nil if panes.empty?
    stages = []
    panes.each do |p|
      next if p.kanban_state.nil?
      next if p.kanban_state.is_closed == true
      state = p.kanban_state
      stage = state.kanban_stage

      st = stages.detect {|s| s[:stage].id == stage.id}
      if !st
        stages << {:stage => stage, :panes => ([] << p), :states => ([]<<state)}
      else
        st[:panes] << p
        st[:states] << state
      end
    end
    stages
  end

  def states(panes)
    return nil if panes.empty?
    panes.collect {|p| p.kanban_state}.sort {|x,y| x.position <=> y.position}
  end

  def show
  end

  def new
    @kanban = Kanban.new
    @project = Project.find(params[:project_id])
    @kanbans = Kanban.find_all_by_project_id(params[:project_id])
    if @kanbans.nil?
      @trackers = Tracker.all
      @copiable_kanbans = Kanbans.all
    else
      used_trackers = []
      @kanbans.each {|k| used_trackers << k.tracker if k.is_valid}
      @trackers = Tracker.all.reject {|t| used_trackers.include?(t)}
    end

    @copiable_kanbans = Kanban.find(:all, :conditions => ["tracker_id in (?) and is_valid = ?", @trackers.select{|t| t.id}, true])
    @copiable_kanbans.each do |k|
	   if k.project.nil?
	      k.name += " - Deleted Project"
	   else
	      k.name += " - #{k.project.name}"
	   end
	end
  end

  def create
    @kanban = Kanban.new(params[:kanban])
    @kanban.created_by = User.current.id
    @kanban.project_id = params[:project_id]
    if request.post? && @kanban.save
      redirect_to settings_project_path(params[:project_id], :tab => 'Kanban')
    else
      render :action => 'new'
    end
  end


  def kanban_settings_tabs
    tabs = [{:name => 'General', :action => :kanban_general, :partial => 'general', :label => :label_kanban_general},
            {:name => 'Panes', :action => :kanban_pane, :partial => 'panes', :label => :label_kanban_panes},
            {:name => 'Workflow', :action => :kanban_workflow, :partial => 'workflow', :label => :label_kanban_workflow},
            {:name => 'Config', :action => :kanban_pane, :partial => 'card_fieldssetup', :label => :label_card_fields_setup}
    ]
    #tabs.select {|tab| User.current.allowed_to?(tab[:action], @project)}
  end


  def update
    @project = Project.find(params[:project_id])
    @kanban = Kanban.find(params[:id])
    if (params[:position])
      @kanban.kanban_pane.each {|p| p.position = params[:position].index("#{p.id}") + 1; p.save}
    end
    if (params[:kanban])
      @kanban.description = params[:kanban][:description]
      @kanban.tracker_id  = params[:kanban][:tracker_id]
      @kanban.name  = params[:kanban][:name]
      @kanban.update_attributes(:is_valid => params[:kanban][:is_valid],:subproject_enable=>params[:kanban][:subproject_enable]);
      @kanban.save
    end
    if @kanban.is_valid == true
      if @project.issues.present?
        @kanban.kanban_pane.each do |each_pane|
          #issues = @project.issues.where(:status_id=>each_pane.kanban_state.issue_status.last.id) if each_pane.kanban_state.issue_status.present?
          issues = @project.issues.where(:status_id=>each_pane.kanban_state.issue_status.map(&:id),:tracker_id=>@kanban.tracker_id) if each_pane.kanban_state.issue_status.present?
          if issues.present?
            issues.each do |each_issue|
              kanban_new = KanbanCard.find_or_initialize_by_issue_id_and_kanban_pane_id(each_issue.id,each_pane.id)
              kanban_new.issue_id = each_issue.id
              kanban_new.developer_id= each_issue.assigned_to_id
              kanban_new.verifier_id=each_issue.assigned_to_id
              kanban_new.kanban_pane_id=each_pane.id
              kanban_new.save
            end
          end
        end
      end

      if params[:kanban].present? && params[:kanban][:subproject_enable].present? && params[:kanban][:subproject_enable] == "1"
        @kanban.kanban_pane.each do |each_pane|
          @subprojects = @project.descendants.active
          @subprojects_ids = @subprojects.map(&:id).join(',') if @subprojects.present?
          issues=[]
          if each_pane.kanban_state.present? && each_pane.kanban_state.issue_status.present? && each_pane.kanban_state.issue_status.last.id.present? && @subprojects_ids.present?
            issues = Issue.find_by_sql("select * from issues where project_id in (#{@subprojects_ids}) and status_id in (#{each_pane.kanban_state.issue_status.map(&:id).join(',')}) and tracker_id in (#{@kanban.tracker_id});");
          end

          if issues.present?
            issues.each do |each_issue|
              # kanban_new = KanbanCard.find_or_initialize_by_issue_id_and_kanban_pane_id(each_issue.id,each_pane.id)
              kanban_new = KanbanCard.where(:issue_id=>each_issue.id,:kanban_pane_id=>each_pane.id).first_or_initialize
              kanban_new.issue_id = each_issue.id
              kanban_new.developer_id= each_issue.assigned_to_id
              kanban_new.verifier_id=each_issue.assigned_to_id
              kanban_new.kanban_pane_id=each_pane.id
              kanban_new.save
            end
          end
        end
      end
      if  params[:kanban].present? && params[:kanban][:subproject_enable].present? && params[:kanban][:subproject_enable] == "0"

        @kanban.kanban_pane.each do |each_pane|
          @subprojects = @project.descendants.active
          # @subprojects_ids= @subprojects.map(&:id) if @subprojects.present?
          #
          # issues = KanbanPane.find_by_sql("select * from issues where project_id in (#{@subprojects_ids}) and status_id in (#{each_pane.kanban_state.issue_status.last.id});");

          @subprojects_ids = @subprojects.map(&:id).join(',') if @subprojects.present?

          issues=[]
          if each_pane.kanban_state.present? && each_pane.kanban_state.issue_status.present? && each_pane.kanban_state.issue_status.last.id.present? && @subprojects_ids.present?
            # issues = Issue.find_by_sql("select * from issues where project_id in (#{@subprojects_ids}) and status_id in (#{each_pane.kanban_state.issue_status.last.id});");
            # issues = Issue.find_by_sql("select * from issues where project_id in (#{@subprojects_ids}) and status_id in (#{each_pane.kanban_state.issue_status.last.id}) and tracker_id in (#{@kanban.tracker_id});");
            issues = Issue.find_by_sql("select * from issues where project_id in (#{@subprojects_ids}) and status_id in (#{each_pane.kanban_state.issue_status.map(&:id).join(',')}) and tracker_id in (#{@kanban.tracker_id});");

          end


          if issues.present?
            KanbanCard.where(:issue_id=>issues.map(&:id)).destroy_all

          end
        end

      end

    end
    respond_to do |format|
      format.json {render :nothing => true}
      format.html do
        if (params[:position])
          render :partial => "edit_js"
        else
          redirect_to settings_project_path(params[:project_id], :tab => 'Kanban')
        end
      end
    end
  end

  def edit
    @project = Project.find(params[:project_id])
    @kanban = Kanban.find(params[:id])
    @kanbans = Kanban.find_all_by_project_id(params[:project_id])
    @roles = Role.all
    if @kanbans.nil?
      @trackers = Tracker.all
    else
      used_trackers = []
      @kanbans.each {|k| used_trackers << k.tracker if k.is_valid and k.id != params[:id].to_i}
      @trackers = Tracker.all.reject {|t| used_trackers.include?(t)}
    end
  end

  def destroy
    puts params
    @kanban = Kanban.find(params[:id])
    @kanban.update_attribute(:is_valid, false);
    @saved = @kanban.save
    respond_to do |format|
      format.js do
        render :partial => "update"
      end
      format.html { redirect_to :controller => 'projects', :action => 'settings', :id => params[:project_id], :tab => 'Kanban' }
    end
  end

  # create a new kanban by copying reference.
  def copy
    ref_kanban = Kanban.find(params[:ref_id])
    ref_kanban_panes = KanbanPane.find_all_by_kanban_id(params[:ref_id])
    ref_workflow = KanbanWorkflow.find_all_by_kanban_id(params[:ref_id])

    new_kanban = ref_kanban.dup
    new_kanban.project_id = params[:project_id]
    new_kanban.update_attribute(:is_valid, true)
    new_kanban.save!
    ref_kanban_panes.each do |p|
      new_pane = p.dup
      new_pane.kanban_id = new_kanban.id
      new_pane.save!
    end

    ref_workflow.each do |w|
      new_w = w.dup
      new_w.kanban_id = new_kanban.id
      new_w.save!
    end
    redirect_to edit_project_kanban_path(new_kanban.project_id, new_kanban.id, :tab => "Panes")
  end

  def pane(pane_id)
    pane = KanbanPane.find(pane_id)
  end

  def stage(pane_id)
    pane = pane(pane_id)
    stage = Stage.find(pane.stage_id) if !pane.nil?
  end


  def kanban_issue_show


    @issue = Issue.find(params[:issue_id])
    @project = @issue.project

    @relations = @issue.relations.select {|r| r.other_issue(@issue) && r.other_issue(@issue).visible? }
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
    @priorities = IssuePriority.active
    @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
    @relation = IssueRelation.new



    # @roles = @user.roles_for_project(@project)

    @time_entry = TimeEntry.new

    @project = @issue.project#Get member name of this project
    @members= @project.members
    @principals = @project.principals
    @user = User.current
    @versions = @project.versions

    @roles = @user.roles_for_project(@project)

    @member = nil
    @principal = nil

    @issue_statuss = IssueStatus.all
    @kanban_states = KanbanState.all
    @issue_status_kanban_state = IssueStatusKanbanState.all
    @kanban_flows = KanbanWorkflow.all

    params[:kanban_id] = 0 if params[:kanban_id].nil?
    params[:member_id] = 0 if params[:member_id].nil?
    params[:principal_id] = 0 if params[:principal_id].nil?

    @kanbans = []

    if params[:kanban_id].to_i > 0
      @kanbans << Kanban.find(params[:kanban_id])
    else
      @kanbans = Kanban.by_project(@project).where("is_valid = ?",true)
    end

    if params[:member_id].to_i == 0 and params[:principal_id].to_i == 0
      @view = PROJECT_VIEW
    elsif params[:member_id].to_i > 0
      @view = MEMBER_VIEW
      @member = Member.find(params[:member_id])
    else
      @view = GROUP_VIEW
      @principal = Principal.find(params[:principal_id])
    end

    @kanban_status_id = params[:kanban_status_id]
    @issue_status_id = params[:issue_status_id]
    @kanban_pane_id = params[:kanban_pane_id]

     # issue = @issue
    respond_to do |format|
      format.html
      format.js
      format.json
    end

 end

  def update_form
    # @issue = Issue.find(params[:id])
    # @project = @issue.project
    #
    @relations = @issue.relations.select {|r| r.other_issue(@issue) && r.other_issue(@issue).visible? }
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
    @priorities = IssuePriority.active
    @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
    @relation = IssueRelation.new
    @time_entry = TimeEntry.new
    @project = @issue.project#Get member name of this project
    @members= @project.members
    @principals = @project.principals
    @user = User.current
    @versions = @project.versions

    @roles = @user.roles_for_project(@project)

    @member = nil
    @principal = nil
    #
    @issue_statuss = IssueStatus.all
    @kanban_states = KanbanState.all
    @issue_status_kanban_state = IssueStatusKanbanState.all
    @kanban_flows = KanbanWorkflow.all
    #
    params[:kanban_id] = 0 if params[:kanban_id].nil?
    params[:member_id] = 0 if params[:member_id].nil?
    params[:principal_id] = 0 if params[:principal_id].nil?

    @kanbans = []

    if params[:kanban_id].to_i > 0
      @kanbans << Kanban.find(params[:kanban_id])
    else
      @kanbans = Kanban.by_project(@project).where("is_valid = ?",true)
    end

    if params[:member_id].to_i == 0 and params[:principal_id].to_i == 0
      @view = PROJECT_VIEW
    elsif params[:member_id].to_i > 0
      @view = MEMBER_VIEW
      @member = Member.find(params[:member_id])
    else
      @view = GROUP_VIEW
      @principal = Principal.find(params[:principal_id])
    end

    @kanban_status_id = params[:kanban_status_id]
    @issue_status_id = params[:issue_status_id]
    @kanban_pane_id = params[:kanban_pane_id]
    #
    with_format :html do
      @html_content = render_to_string partial: 'kanbans/issues/edit'
    end

    respond_to do |format|
      # render :json => { :attachmentPartial => render_to_string('adsprints/sprint_render', :layout => false, :locals => { :message => "@message" }) }
      format.js {
        render :json => { :editcardPartial => @html_content,:issue_status_id=> @issue_status_id,:kanban_status_id=>@kanban_status_id,:kanban_pane_id=>@kanban_pane_id }
      }
    end


  end


# Ajax find kanban state id

  def find_kanban_state_id
    issues_status_id = params[:issue_status_id]
    issue_states = IssueStatusKanbanState.where(:issue_status_id=>issues_status_id)
    if issue_states.present?
      kanban_state_id = issue_states.map(&:kanban_state_id).first
    end

    if request.xhr?
      render :json => {
          :kanban_state_id=> kanban_state_id
      }
    end

  end

  # Ajax find issue state id.
  def find_issue_status_id

    # @issue_state = IssueStatusKanbanState.where(issue_statue_id: params[:issue_status_id])
    # @kanban_status_id = params[:kanban_status_id]
    kanban_state_id = params[:kanban_state_id]
    kanban_states = IssueStatusKanbanState.where(:kanban_state_id=>kanban_state_id)

    if kanban_states.present?
      issue_status_id = kanban_states.map(&:issue_status_id).first
    end

    if request.xhr?
      render :json => {
          :issue_status_id=> issue_status_id
      }
    end

  end


  # TODO: Changing tracker on an existing issue should not trigger this
  def build_new_issue_from_params
    if params[:id].blank?
      @issue = Issue.new
      if params[:copy_from]
        begin
          @copy_from = Issue.visible.find(params[:copy_from])
          @copy_attachments = params[:copy_attachments].present? || request.get?
          @copy_subtasks = params[:copy_subtasks].present? || request.get?
          @issue.copy_from(@copy_from, :attachments => @copy_attachments, :subtasks => @copy_subtasks)
        rescue ActiveRecord::RecordNotFound
          render_404
          return
        end
      end
      @issue.project = @project
    else
      @issue = @project.issues.visible.find(params[:id])
    end

    @issue.project = @project
    @issue.author ||= User.current
    # Tracker must be set before custom field values
     @issue.tracker ||= @project.trackers.find((params[:issue] && params[:issue][:tracker_id]) || params[:tracker_id] || :first)
    if @issue.tracker.nil?
      render_error l(:error_no_tracker_in_project)
      return false
    end
    @issue.start_date ||= Date.today if Setting.default_issue_start_date_to_creation_date?
    @issue.safe_attributes = params[:issue]

    @priorities = IssuePriority.active
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current, @issue.new_record?)
    @available_watchers = @issue.watcher_users
    if @issue.project.users.count <= 20
      @available_watchers = (@available_watchers + @issue.project.users.sort).uniq
    end
  end

  def find_project
    project_id = params[:project_id] || (params[:issue] && params[:issue][:project_id])
    @project = Project.find(project_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end


end
