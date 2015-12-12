class AdsprintsController < ApplicationController
  unloadable

  helper :journals
  helper :projects
  include ProjectsHelper
  include ApplicationHelper
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
  helper :application
  include Redmine::Export::PDF

  respond_to :html, :js
  before_filter :find_project
  before_filter :build_new_issue_from_params, :only => [:add_issue_to_sprint,:create_issue_to_sprint]
  before_filter :check_for_default_issue_status

  def list
    @backlog = SprintsTasks.get_backlog(@project)
    @sprints = Sprints.all_sprints(@project)
    @sprints.each{|s| s['tasks'] = SprintsTasks.get_tasks_by_sprint(@project, [s.id])}
    @assignables = {}
    @project.assignable_users.each{|u| @assignables[u.id] = u.firstname + ' ' + u.lastname}
    @project_id = @project.id
    @plugin_path = File.join(Redmine::Utils.relative_url_root, 'plugin_assets', 'AgileDwarf')
    @closed_status = Setting.plugin_AgileDwarf[:stclosed].to_i
  end

  def create_sprint
    @sprints = Sprints.new(params[:sprints])
    @project_id = @project.id
    @plugin_path = File.join(Redmine::Utils.relative_url_root, 'plugin_assets', 'AgileDwarf')
    @closed_status = Setting.plugin_AgileDwarf[:stclosed].to_i
    if @sprints.save
      with_format :html do
        @html_content = render_to_string partial: 'adsprints/sprint',:locals => { :sprint => @sprints }
      end

       respond_to do |format|
          # render :json => { :attachmentPartial => render_to_string('adsprints/sprint_render', :layout => false, :locals => { :message => "@message" }) }
          format.js {
            render :json => { :sprintPartial => @html_content,:sprint_id=>@sprints.id }
          }
        end

    else
      # This line overrides the default rendering behavior, which
      # would have been to render the "create" view.
      respond_to do |format|
      format.js {
        @errors = ""
        render :json => {
                   :errors=> @sprints.errors.full_messages.each {|s| @errors += (s + "</br>")}
               }
      }
        end
    end

  end


  def update_sprint
    # @sprints = Sprints.new(params[:sprints])

    @sprints = Sprints.find(params[:sprint_id])


    @project_id = @project.id
    @plugin_path = File.join(Redmine::Utils.relative_url_root, 'plugin_assets', 'AgileDwarf')
    @closed_status = Setting.plugin_AgileDwarf[:stclosed].to_i
    if @sprints.update_attributes(params[:sprints])
      with_format :html do
        @html_content = render_to_string partial: 'adsprints/sprint',:locals => { :sprint => @sprints }
      end

      respond_to do |format|
        # render :json => { :attachmentPartial => render_to_string('adsprints/sprint_render', :layout => false, :locals => { :message => "@message" }) }
        format.js {
          render :json => { :sprintPartial => @html_content,:sprint_id=>@sprints.id }
        }
      end

    else
      # This line overrides the default rendering behavior, which
      # would have been to render the "create" view.
      respond_to do |format|
        format.js {
          @errors = ""
          render :json => {
              :errors=> @sprints.errors.full_messages.each {|s| @errors += (s + "</br>")}
          }
        }
      end
    end

  end




  def add_issue_to_sprint
    # @project = Project.find(params[:project_id])
    # respond_to do |format|
    #   format.html { render :action => 'add_issue_to_sprint', :layout => !request.xhr? }
    # end

    respond_to do |format|
      format.html
      format.js
      format.json
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


  def create_issue_to_sprint
    call_hook(:controller_issues_new_before_save, { :params => params, :issue => @issue })
    @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
    if @issue.save
      call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
      @plugin_path = File.join(Redmine::Utils.relative_url_root, 'plugin_assets', 'AgileDwarf')
      @closed_status = Setting.plugin_AgileDwarf[:stclosed].to_i
      with_format :html do
        @html_content = render_to_string partial: 'adsprints/sprint_render', :locals => { :message => "@message" }
      end
      respond_to do |format|
        # render :json => { :attachmentPartial => render_to_string('adsprints/sprint_render', :layout => false, :locals => { :message => "@message" }) }
        format.js {
        render :json => { :attachmentPartial => @html_content,:sprint_id=>@issue.fixed_version_id }
        }
      end
      # return
    else
      respond_to do |format|
        format.html { render :action => 'new' }
        # format.api  { render_validation_errors(@issue) }
        @errors=""
        @issue.errors.full_messages.each do |s|
          @errors += ("<li>"+s+"</li>")
        end
        format.js {
            render :json => {
                     :errors=> @errors
              }
        }



      end
    end
  end

  def check_for_default_issue_status
    if IssueStatus.default.nil?
      render_error l(:error_no_default_issue_status)
      return false
    end
  end

  def new
    # @time_entry = TimeEntry.new
    @sprint = Sprints.new

  end
  def edit

    @sprint = Sprints.find(params[:sprint_id])

  end

  private

  # def find_project
  #   # @project variable must be set before calling the authorize filter
  #   @project = Project.find(params[:project_id])
  # end

  def find_project
    project_id = params[:project_id] || (params[:issue] && params[:issue][:project_id])
    @project = Project.find(project_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end