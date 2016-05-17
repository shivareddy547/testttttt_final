class MetricsController < ApplicationController
  unloadable

  require 'spreadsheet'
  require 'rubyXL'
  require 'stringio'
  Spreadsheet.client_encoding = 'UTF-8'
  default_search_scope :issues

  before_filter :authorize, :except => [:index]
  before_filter :find_optional_project, :only => [:index]
  accept_rss_auth :index
  accept_api_auth :index


  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

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


  def index
    retrieve_query
    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a
    @project = Project.find(params[:project_id])
    @query.project_id = @project.id



    if @query.valid?

      @limit = per_page_option
      @issue_count = @query.issue_count
      @issue_pages = Paginator.new @issue_count, @limit, params['page']
      @offset ||= @issue_pages.offset
      if params[:metrics_filter].present?
        @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
                                :order => sort_clause
        )
      else

      @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
                              :order => sort_clause,
                              :offset => @offset,
                              :limit => @limit)
      end
      @issue_count_by_group = @query.issue_count_by_group

      respond_to do |format|
        format.html #{ render :template => 'issues/index', :layout => !request.xhr? }
        format.api  {
          Issue.load_visible_relations(@issues) if include_in_api_response?('relations')

        }
        # format.atom #{ render_feed(@issues, :title => "#{@project || Setting.app_title}: #{l(:label_issue_plural)}") }
        # format.csv  { send_data(query_to_csv(@issues, @query, params), :type => 'text/csv; header=present', :filename => 'issues.csv') }
        #  format.pdf  { send_data(issues_to_pdf(@issues, @project, @query), :type => 'application/pdf', :filename => 'issues.pdf') }
        format.pdf  { send_data(issues_to_pdf(@issues, @project, @query), :type => 'application/pdf', :filename => 'issues.pdf') }

        # format.xls  { send_data spreadsheet.string, :filename => "metrics.xls", :type =>  "application/vnd.ms-excel" }
         format.xlsx  { send_data Metric.query_to_excelx(@issues, @query, params,@project.identifier, params[:role_for_xl]), :filename => "#{@project.identifier}.xlsx", :type =>  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }
        # format.xlsx do
        #   response.headers['Content-Disposition'] = "attachment; filename=users.xlsx"
        # end
      end
    else
      respond_to do |format|
        format.html #{ render(:template => 'issues/index', :layout => !request.xhr?) }
        format.any(:atom, :csv, :pdf) { render(:nothing => true) }
        format.api { render_validation_errors(@query) }
        format.xls
      end
    end


    # send_file file_path, :type=>'text/csv'
  rescue ActiveRecord::RecordNotFound
    render_404
  end


  def get_issues_for_excel

    retrieve_query
    @project = Project.find_by_identifier('dmo')
    @child_projects = @project.children
    # @child_projects.each do |each_project|
    #
    #
    #
    # end
    @find_target_version = Sprints.where(:project_id=>@project.id).order('created_on ASC').last
    @find_target_version

    # @issues = Issue.where

  end


  def retrieve_query
    params = {"utf8"=>"✓", "set_filter"=>"1", "f"=>["status_id", ""], "op"=>{"status_id"=>"o"}, "c"=>["tracker", "status", "priority", "subject", "assigned_to", "updated_on", "estimated_hours", "due_date"], "group_by"=>"", "project_id"=>"dmo"}

    if !params[:query_id].blank?
      cond = "project_id IS NULL"
      cond << " OR project_id = #{@project.id}" if @project
      @query = IssueQuery.where(cond).find(params[:query_id])
      raise ::Unauthorized unless @query.visible?
      @query.project = @project
      session[:query] = {:id => @query.id, :project_id => @query.project_id}
      sort_clear
    elsif api_request? || params[:set_filter] || session[:query].nil? || session[:query][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = IssueQuery.new(:name => "_")
      @query.project = @project
      @query.build_from_params(params)
      session[:query] = {:project_id => @query.project_id, :filters => @query.filters, :group_by => @query.group_by, :column_names => @query.column_names}
    else
      # retrieve from session
      @query = nil
      @query = IssueQuery.find_by_id(session[:query][:id]) if session[:query][:id]
      @query ||= IssueQuery.new(:name => "_", :filters => session[:query][:filters], :group_by => session[:query][:group_by], :column_names => session[:query][:column_names])
      @query.project = @project
    end
  end


end
