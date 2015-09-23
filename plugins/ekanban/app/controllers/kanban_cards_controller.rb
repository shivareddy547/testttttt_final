class KanbanCardsController < ApplicationController
  unloadable
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

  skip_before_filter :check_if_login_required
  skip_before_filter :verify_authenticity_token
  before_filter :build_new_issue_from_params, :only => [:add_new_issue,:create_new_issue]
  def index
  	respond_to :json
  end

  def create
  end

  def show
  	respond_to :json,:html
  	@card = KanbanCard.find(params[:id])
  	@issue = @card.issue
  	respond_with([@card,@issue])
  end

  def save_with_issues()
    Issue.transaction do
      # TODO: Rename hook
      #must save @issue first, otherwise, the wip check will failed.
       return @card.save if @issue.save
    end
    false
  end

  def update

    @issue = Issue.find(params[:issue_id])
    return unless update_issue_from_params
    @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
    saved = false
    begin
      saved = save_issue_with_child_records
      @issue.status_id = params[:issue_status_id]
    rescue ActiveRecord::StaleObjectError
      @conflict = true
      if params[:last_journal_id]
        @conflict_journals = @issue.journals_after(params[:last_journal_id]).all
        @conflict_journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @issue.project)
      end
    end
    # @issue = Issue.find(params[:issue_id])
    @card = KanbanCard.find_by_issue_id(params[:issue_id])
    old_card = @card.dup

    # @journal = @issue.init_journal(User.current, params[:comment][:notes])
    #
    @issue.status_id = params[:issue_status_id]
    if params[:kanban_state_id].nil?
	   pane = KanbanPane.find(params[:kanban_pane_id])
    else
    	pane = KanbanPane.find_by_kanban_id_and_kanban_state_id(@card.kanban_pane.kanban.id, params[:kanban_state_id])
    end
    @card.kanban_pane_id = pane.id

    saved = false
    begin
      saved = save_with_issues();
    rescue ActiveRecord::StaleObjectError
    end
    # KanbanCardJournal.build(old_card,@card,@journal) if @saved == true

    if !saved

      @errors = ""
      @issue.errors.full_messages.each {|s| @errors += (s + ";")}
    end
  	respond_to do |format|
      format.json do
        if saved
          # project_id = @card.kanban_pane.kanban.project_id
          # redirect_to project_kanbans_path(project_id)
          if request.xhr?
            render :json => {
                :issue=> @issue.subject
            }
          end
        else
         # render :nothing => true
          if request.xhr?
            render :json => {
                :errors=> @issue.errors.full_messages.each {|s| @errors += (s + "</br>")}
            }
          end
        end
      end
      format.js do
        render :partial => "update"
      end
    end
  end


  # TODO: Refactor, not everything in here is needed by #edit
  def update_issue_from_params
    @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
    @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
    @time_entry.attributes = params[:time_entry]

    @issue.init_journal(User.current)

    issue_attributes = params[:issue]
    if issue_attributes && params[:conflict_resolution]
      case params[:conflict_resolution]
        when 'overwrite'
          issue_attributes = issue_attributes.dup
          issue_attributes.delete(:lock_version)
        when 'add_notes'
          issue_attributes = issue_attributes.slice(:notes)
        when 'cancel'
          redirect_to issue_path(@issue)
          return false
      end
    end
    @issue.safe_attributes = issue_attributes
    @priorities = IssuePriority.active
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    true
  end


# Saves @issue and a time_entry from the parameters
  def save_issue_with_child_records
    Issue.transaction do
      if params[:time_entry] && (params[:time_entry][:hours].present? || params[:time_entry][:comments].present?) && User.current.allowed_to?(:log_time, @issue.project)
        time_entry = @time_entry || TimeEntry.new
        time_entry.project = @issue.project
        time_entry.issue = @issue
        time_entry.user = User.current
        time_entry.spent_on = User.current.today
        time_entry.attributes = params[:time_entry]
        @issue.time_entries << time_entry
      end

      call_hook(:controller_issues_edit_before_save, { :params => params, :issue => @issue, :time_entry => time_entry, :journal => @issue.current_journal})
      if @issue.save
        call_hook(:controller_issues_edit_after_save, { :params => params, :issue => @issue, :time_entry => time_entry, :journal => @issue.current_journal})
      else
        raise ActiveRecord::Rollback
      end
    end
  end


  def card_filelds_setup

    kanban = Kanban.find(params[:kanban_id])
    kanban.card_selected_display_columns = params[:settings][:issue_list_default_columns] if params[:settings].present? && params[:settings][:issue_list_default_columns].present?
    kanban.card_selected_tooltip_columns = params[:settings][:issue_list_tooltip_default_columns] if params[:settings].present? && params[:settings][:issue_list_tooltip_default_columns].present?
    kanban.save
    redirect_to edit_project_kanban_path(params[:project_id],params[:id], :tab => 'Config')

  end

  def log_entry_new

    @time_entry ||= TimeEntry.new(:project => @project, :issue => @issue, :user => User.current, :spent_on => User.current.today)
    @time_entry.safe_attributes = params[:time_entry]
    # @time_entry = TimeEntry.new
  end

  def add_new_issue
    # @project = Project.find(params[:project_id])
    # respond_to do |format|
    #   format.html { render :action => 'add_issue_to_sprint', :layout => !request.xhr? }
    # end
   @project = Project.find_by_id(params[:project_id])
    respond_to do |format|
      format.html
      format.js
      format.json
    end

  end

  # TODO: Changing tracker on an existing issue should not trigger this
  def build_new_issue_from_params
    @project = Project.find_by_id(params[:project_id])
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


  def create_new_issue
    call_hook(:controller_issues_new_before_save, { :params => params, :issue => @issue })
    @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
    if @issue.save
      call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
      @plugin_path = File.join(Redmine::Utils.relative_url_root, 'plugin_assets', 'AgileDwarf')
      @closed_status = Setting.plugin_AgileDwarf[:stclosed].to_i
      # with_format :html do
      #   @html_content = render_to_string partial: 'adsprints/sprint_render', :locals => { :message => "@message" }
      # end
      respond_to do |format|
        # render :json => { :attachmentPartial => render_to_string('adsprints/sprint_render', :layout => false, :locals => { :message => "@message" }) }
        format.js {
          render :json => { :attachmentPartial => "success" }
        }
      end
      # return
    else
      respond_to do |format|

        # format.api  { render_validation_errors(@issue) }
        format.js {
          @errors = ""
          render :json => {
                     :errors=> @issue.errors.full_messages.each {|s| @errors += (s + "</br>")}
                 }
        }
      end
    end
  end


  # def log_entry_create
  #
  #
  # end


  def log_entry_create
    @time_entry ||= TimeEntry.new(:project => @project, :issue => @issue, :user => User.current, :spent_on => User.current.today)
    @time_entry.safe_attributes = params[:time_entry]
    if @time_entry.project && !User.current.allowed_to?(:log_time, @time_entry.project)
      render_403
      return
    end

    call_hook(:controller_timelog_edit_before_save, { :params => params, :time_entry => @time_entry })

    if @time_entry.save
      respond_to do |format|
        format.html {
          flash[:notice] = l(:notice_successful_create)
        }
        format.js {
          #flash[:notice] = l(:notice_successful_create)
          render :json => {
              :time_entry_message=> "Success"
          }

        }

      end
    else
      respond_to do |format|
        format.html { render :action => 'new' }
        format.js {
          @errors = ""
          render :json => {
              :errors=> @time_entry.errors.full_messages.each {|s| @errors += (s + "</br>")}
          }
        }
      end
    end
  end



end