require 'csv'
class TimelogImportController < ApplicationController
   unloadable
  before_filter :find_project

  ISSUE_ATTRS = [:id,:spent_on,:status,:activity,:time_spent,:comments,:user,:by]

  def index
    session[:failed_issues] = []
    session[:headers] =[]
  end

  def match

  # Delete existing iip to ensure there can't be two iips for a user
    @messages = Array.new
    TimelogImportInProgres.delete_all(["user_id = ?",User.current.id])
    @original_filename = params[:file].original_filename if params[:file].present?
    file_extension =  File.extname(@original_filename) if @original_filename.present?
    if params[:file].present? && file_extension == ".csv"
      #validate_file = TimelogImportInProgres.import(params[:file])
   # save import-in-progress data
    iip = TimelogImportInProgres.find_or_create_by_user_id(User.current.id)
    iip.quote_char = params[:wrapper]
    iip.col_sep = params[:splitter]
    iip.encoding = params[:encoding]
    iip.created = Time.new
    iip.csv_data = params[:file].read
    iip.save
    # Put the timestamp in the params to detect
    # users with two imports in progress
    @import_timestamp = iip.created.strftime("%Y-%m-%d %H:%M:%S")
    @original_filename = params[:file].original_filename
    file_extension =  File.extname(@original_filename)
    # display sample
    if file_extension == ".csv"
    sample_count = 5
    i = 0
    @samples = []
    CSV.new(iip.csv_data, {:headers=>true,
                           :encoding=>iip.encoding,
                           :quote_char=>iip.quote_char,
                           :col_sep=>iip.col_sep}).each do |row|
      @samples[i] = row
      i += 1
      if i >= sample_count
        break
      end
    end # do

    if @samples.size > 0
      @headers = @samples[0].headers
    end

    # fields
    @attrs = Array.new
    ISSUE_ATTRS.each do |attr|
      #@attrs.push([l_has_string?("field_#{attr}".to_sym) ? l("field_#{attr}".to_sym) : attr.to_s.humanize, attr])
      @attrs.push([l_or_humanize(attr, :prefix=>"field_"), attr])
    end
    @project.all_issue_custom_fields.each do |cfield|
      @attrs.push([cfield.name, cfield.name])
    end
    IssueRelation::TYPES.each_pair do |rtype, rinfo|
      @attrs.push([l_or_humanize(rinfo[:name]),rtype])
    end
    #@attrs.sort!
    else
      @messages << "Please attach csv format file."
     end
    else
      @messages << "Please attach CSV format file"
      end
  end

  def result
    @failed_issues_colle=[]
    @handle_count = 0
    @update_count = 0
    @skip_count = 0
    @failed_count = 0
    @failed_issues = Hash.new
    @messages = Array.new
    session[:failed_issues] ||= []
    session[:headers] ||=[]
    @external_activity=''
    @affect_projects_issues = Hash.new
    # This is a cache of previously inserted issues indexed by the value
    # the user provided in the unique column
    @issue_by_unique_attr = Hash.new
    # Cache of user id by login
    @user_by_login = Hash.new
    # Cache of Version by name
    @version_id_by_name = Hash.new

    # Retrieve saved import data
    iip = TimelogImportInProgres.find_by_user_id(User.current.id)
    if iip == nil
      flash[:error] = "No import is currently in progress"
      return
    end
    if iip.created.strftime("%Y-%m-%d %H:%M:%S") != params[:import_timestamp]
      flash[:error] = "You seem to have started another import " \
          "since starting this one. " \
          "This import cannot be completed"
      return
    end

    fields_map = {}
    params[:fields_map].each { |k, v| fields_map[k.unpack('U*').pack('U*')] = v }
    # attrs_map is fields_map's invert
    attrs_map = fields_map.invert
    # check params
    unique_error = nil
    CSV.new(iip.csv_data, {:headers=>true,
                           :encoding=>iip.encoding,
                           :quote_char=>iip.quote_char,
                           :col_sep=>iip.col_sep}).each do |row|
       project = Project.find_by_name(row[attrs_map["project"]])
      if !project
        project = @project
      end
      begin
        row.each do |k, v|
          k = k.unpack('U*').pack('U*') if k.kind_of?(String)
          v = v.unpack('U*').pack('U*') if v.kind_of?(String)

          row[k] = v
        end

        tracker = Tracker.find_by_name(row[attrs_map["tracker"]])
        if row[attrs_map["by"]]
          user = User.where(:mail=>row[attrs_map["by"]])
        end


        time_entry = TimeEntry.new
        @activity_id=''
        # required attributes
        TimeEntryActivity.active.each do |activity|
          if activity.name == row[attrs_map["activity"]]
            @activity_id = activity.id
          end

        end

        time_entry.activity_id = @activity_id != nil ? @activity_id : ''
        if row[attrs_map["by"]]
          user = User.where(:mail=>row[attrs_map["by"]])
        end
        if user.present? && user.last.projects.present? && user.last.projects.include?(@project)
        time_entry.user_id = user.present? ? user.last.id : ''
        end
        if User.current.projects.map(&:id).include?(@project.id)
        time_entry.project_id = @project != nil ? @project.id : ''
        end
        time_entry.hours = row[attrs_map["time_spent"]] != nil ? row[attrs_map["time_spent"]].to_f : ''

       @project.issues.each do |each_issue|
          each_issue.custom_field_values.each_with_index do |c,index|
           custom_field =CustomField.where(:id=>c.custom_field_id)
          if custom_field.present? && (custom_field.last.name=="External ID")

           if each_issue.custom_field_values[index].to_s == row[attrs_map["id"]]

             time_entry.issue_id = each_issue.id
                  #  @external_activity = true
           end
          end
       end
       end

       # Issue.last.custom_field_values.inject({}) {|h,v| h[v.custom_field_id] = v.value; h}

      # time_entry.external_id = row[attrs_map["id"]] != nil ? row[attrs_map["id"]] : ''
        time_entry.comments = row[attrs_map["comments"]] != nil ? row[attrs_map["comments"]] : ''
        if row[attrs_map["spent_on"]].present?
          date_conversion = row[attrs_map["spent_on"]].to_date rescue nil
         if date_conversion.present? &&  (2004 < date_conversion.year.to_i) && (date_conversion.year.to_i < 2024)
          time_entry.spent_on = date_conversion
          end
        end

        custom_failed_count = 0
        next if custom_failed_count > 0
        # watchers
        watcher_failed_count = 0
        next if watcher_failed_count > 0

        unless time_entry.save
          @failed_count += 1
          @failed_issues[@failed_count] = row if row.present?
         @failed_issues_colle << [@failed_count,@failed_issues[@failed_count]]
          @messages << "Warning: The following data-validation errors occurred on issue #{@failed_count} in the list below"
          time_entry.errors.each do |attr, error_message|
            if attr == "user_id".to_sym
               attr = "By"
               if row[attrs_map["by"]].present?
               error_message = "Not Matched"
              end
             elsif attr == "activity_id".to_sym
               attr = "Activity"
               if row[attrs_map["activity"]].present?
                 error_message = "Invalid"
               end
             elsif attr == "hours".to_sym
               attr = "Time Spent"

             elsif attr == "spent_on".to_sym
               attr = "Spent On"
                if row[attrs_map["spent_on"]].present?
                 error_message = "Invalid"
                end
             elsif attr == "project_id".to_sym
               attr = "Project"
               if @project.present?
                 error_message = "Project Not Matched"
               end
             elsif attr == "issue_id".to_sym
               attr = "ID"
               if row[attrs_map["id"]].present?
                 error_message = "Invalid"
               end
              end
              @messages << "Error: #{attr} #{error_message}"
          end
        else
          # Issue relations
          @handle_count += 1
        end


      end # do
     if @failed_issues_colle.size > 0
        @failed_issues = @failed_issues_colle.sort
       @headers = @failed_issues[0][1].headers
     end
      if @failed_issues.present?

        session[:failed_issues]=@failed_issues
        session[:headers]=@headers
       # params[:failed_issues]=@failed_issues
      else
        session[:failed_issues] ||=[]
      end

      # Clean up after ourselves
      iip.delete
      # Garbage prevention: clean up iips older than 3 days
      TimelogImportInProgres.delete_all(["created < ?",Time.new - 3*24*60*60])
    end
     end

   def export_csv
     failed_issues = params[:failed_issues]
      # p t = failed_issues.gsub(/[{}:]/,'').split(', ')
     if session[:failed_issues].present?
       data_array=[]
       failed_issues = session[:failed_issues]
       headers = session[:headers]
       student_csv = CSV.generate do |csv|
       csv << headers
       failed_issues.each do |id, issue|
         issue.each do |column|
           data = column[1]
           data = data.unpack('U*').pack('U*') if data.is_a?(String) rescue nil
           data_array << data
         end
         csv<< data_array
       end
     end
       respond_to do |format|
         format.csv do
           send_data(student_csv, :type => 'text/csv', :filename => 'failed_issues.csv')
         end

       end
     end
   end


   private

  def find_project
    @project = Project.find(params[:project_id])
  end


  def flash_message(type, text)
    flash[type] ||= ""
    flash[type] += "#{text}<br/>"
  end
  end
