require 'csv'
require 'tempfile'

class MultipleIssuesForUniqueValue < Exception
end

class NoIssueForUniqueValue < Exception
end

class Journal < ActiveRecord::Base
  def empty?(*args)
    (details.empty? && notes.blank?)
  end
end

class ImporterController < ApplicationController
  unloadable
  
  before_filter :find_project

  ISSUE_ATTRS = [:id, :subject, :assigned_to, :fixed_version,
    :author, :description, :category, :priority, :tracker, :status,
    :start_date, :due_date, :done_ratio, :estimated_hours,
    :parent_issue, :watchers ]
  
  def index
  end

  def match
    @messages = Array.new
    # Delete existing iip to ensure there can't be two iips for a user
    ImportInProgress.delete_all(["user_id = ?",User.current.id])
    @original_filename = params[:file].original_filename if params[:file].present?
    file_extension =  File.extname(@original_filename) if @original_filename.present?
    if params[:file].present? && file_extension == ".csv"
    # save import-in-progress data
    iip = ImportInProgress.find_or_create_by_user_id(User.current.id)
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
    # display sample
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
    puts "++++++++++attribut++++"
    puts @attrs
    puts "+++++++++end ++"
    #@attrs.sort!
    else
      @messages << "Please attach CSV format file"
    end
    else
      @messages << "Please attach CSV format file"
     end

  end
  
  # Returns the issue object associated with the given value of the given attribute.
  # Raises NoIssueForUniqueValue if not found or MultipleIssuesForUniqueValue
  def issue_for_unique_attr(unique_attr, attr_value, row_data)
    if @issue_by_unique_attr.has_key?(attr_value)
      return @issue_by_unique_attr[attr_value]
    end

    if unique_attr == "id"
      issues = [Issue.find_by_id(attr_value)]
    else
      # Use IssueQuery class Redmine >= 2.3.0
      begin
        if Module.const_get('IssueQuery') && IssueQuery.is_a?(Class)
          query_class = IssueQuery
        end
      rescue NameError
        query_class = Query
      end

      query = query_class.new(:name => "_importer", :project => @project)
      query.add_filter("status_id", "*", [1])
      query.add_filter(unique_attr, "=", [attr_value])
      
      issues = Issue.find :all, :conditions => query.statement, :limit => 2, :include => [ :assigned_to, :status, :tracker, :project, :priority, :category, :fixed_version ]
    end
    
    if issues.size > 1
      @failed_count += 1
      @failed_issues[@failed_count] = row_data
      @messages << "Warning: Unique field #{unique_attr} with value '#{attr_value}' in issue #{@failed_count} has duplicate record"
      raise MultipleIssuesForUniqueValue, "Unique field #{unique_attr} with value '#{attr_value}' has duplicate record"
      else
      if issues.size == 0
        raise NoIssueForUniqueValue, "No issue with #{unique_attr} of '#{attr_value}' found"
      end
      issues.first
    end
  end

  # Returns the id for the given user or raises RecordNotFound
  # Implements a cache of users based on login name
  def user_for_login!(login)
    begin
      if !@user_by_login.has_key?(login)
        @user_by_login[login] = User.find_by_login!(login)
      end
    rescue ActiveRecord::RecordNotFound
      if params[:use_anonymous]
        @user_by_login[login] = User.anonymous()
      else
        @unfound_class = "User"
        @unfound_key = login
        raise
      end
    end
    @user_by_login[login]
  end
  def user_id_for_login!(login)
    user = user_for_login!(login)
    user ? user.id : nil
  end
    
  
  # Returns the id for the given version or raises RecordNotFound.
  # Implements a cache of version ids based on version name
  # If add_versions is true and a valid name is given,
  # will create a new version and save it when it doesn't exist yet.
  def version_id_for_name!(project,name,add_versions)
    if !@version_id_by_name.has_key?(name)
      version = Version.find_by_project_id_and_name(project.id, name)
      if !version
        if name && (name.length > 0) && add_versions
          version = project.versions.build(:name=>name)
          version.save
        else
          @unfound_class = "Version"
          @unfound_key = name
          raise ActiveRecord::RecordNotFound, "No version named #{name}"
        end
      end
      @version_id_by_name[name] = version.id
    end
    @version_id_by_name[name]
  end


  def result1
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





  def result

    start_time = Time.now
    @handle_count = 0
    @update_count = 0
    @skip_count = 0
    @failed_count = 0
    @failed_issues = Hash.new
	@messages = Array.new
    @affect_projects_issues = Hash.new
    # This is a cache of previously inserted issues indexed by the value
    # the user provided in the unique column
    @issue_by_unique_attr = Hash.new
    # Cache of user id by login
    @user_by_login = Hash.new
    # Cache of Version by name
    @version_id_by_name = Hash.new
    puts "Time1 elapsed #{(Time.now - start_time)*1000} milliseconds"
    start_time = Time.now
    first_start_time = Time.now

    # Retrieve saved import data
    iip = ImportInProgress.find_by_user_id(User.current.id)
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
    puts "Time2 elapsed #{(Time.now - start_time)*1000} milliseconds"
    start_time = Time.now
    default_tracker = params[:default_tracker]
    update_issue = params[:update_issue]
    unique_field = params[:unique_field].empty? ? nil : params[:unique_field]
    journal_field = params[:journal_field]
    update_other_project = params[:update_other_project]
    ignore_non_exist = params[:ignore_non_exist]
    fields_map = {}
    params[:fields_map].each { |k, v| fields_map[k.unpack('U*').pack('U*')] = v }
    send_emails = params[:send_emails]
    add_categories = params[:add_categories]
    add_versions = params[:add_versions]
    unique_attr = fields_map[unique_field]
    unique_attr_checked = false  # Used to optimize some work that has to happen inside the loop
    puts "Time3 elapsed #{(Time.now - start_time)*1000} milliseconds"
    start_time = Time.now
    # attrs_map is fields_map's invert
    attrs_map = fields_map.invert
    # check params
    unique_error = nil
    if update_issue
      unique_error = l(:text_rmi_specify_unique_field_for_update)
    elsif attrs_map["parent_issue"] != nil
      unique_error = l(:text_rmi_specify_unique_field_for_column,:column => l(:field_parent_issue))
    else
      IssueRelation::TYPES.each_key do |rtype|
        if attrs_map[rtype]
          unique_error = l(:text_rmi_specify_unique_field_for_column,:column => l("label_#{rtype}".to_sym))
          break
        end
      end
    end
    if unique_error && unique_attr == nil
      flash[:error] = unique_error
      return
    end
    puts "Time4 elapsed #{(Time.now - start_time)*1000} milliseconds"
    p '--------------------- i called ----------'
    start_time = Time.now
    connection = ActiveRecord::Base.connection
    sql1 = ''
    CSV.new(iip.csv_data, {:headers=>true,
                           :encoding=>iip.encoding,
                           :quote_char=>iip.quote_char,
                           :col_sep=>iip.col_sep}).each do |row|

      project = Project.find_by_name(row[attrs_map["project"]])
      if !project
        project = @project
      end
      puts "Time5 elapsed #{(Time.now - start_time)*1000} milliseconds raja"
      start_time = Time.now
      begin
        row.each do |k, v|
          k = k.unpack('U*').pack('U*') if k.kind_of?(String)
          v = v.unpack('U*').pack('U*') if v.kind_of?(String)

          row[k] = v
        end
        puts "Time6 elapsed #{(Time.now - start_time)*1000} milliseconds"
        start_time = Time.now
        # tracker = Tracker.find_by_name(row[attrs_map["tracker"]])
        tracker = Tracker.where(:name => (row[attrs_map["tracker"]])).last
        status = IssueStatus.where(:name => (row[attrs_map["status"]])).last
        author = attrs_map["author"] ? user_for_login!(row[attrs_map["author"]]) : User.current
        priority = Enumeration.where(:name => (row[attrs_map["priority"]])).last
        category_name = row[attrs_map["category"]]
        category = IssueCategory.where(:project_id=> project.id,:name=> category_name).last
        if (!category) && category_name && category_name.length > 0 && add_categories
          category = project.issue_categories.build(:name => category_name)
          category.save
        end
        puts "Time7 elapsed #{(Time.now - start_time)*1000} milliseconds"
        start_time = Time.now
        assigned_to = row[attrs_map["assigned_to"]] != nil ? user_for_login!(row[attrs_map["assigned_to"]]) : nil
        fixed_version_name = row[attrs_map["fixed_version"]].blank? ? nil : row[attrs_map["fixed_version"]]
        fixed_version_id = fixed_version_name ? version_id_for_name!(project,fixed_version_name,add_versions) : nil
        watchers = row[attrs_map["watchers"]]
        # new issue or find exists one
        puts "Time8 elapsed #{(Time.now - start_time)*1000} milliseconds"
        start_time = Time.now
        issue = Issue.new
        journal = nil
        issue.project_id =  project != nil ? project.id : @project.id
        issue.tracker_id = tracker != nil ? tracker.id : default_tracker
        issue.author_id =  author != nil ? author.id : User.current.id
        puts "Time9 elapsed #{(Time.now - start_time)*1000} milliseconds"
      rescue ActiveRecord::RecordNotFound
        @failed_count += 1
        @failed_issues[@failed_count] = row
        @messages << "Warning: When adding issue #{@failed_count} below, the #{@unfound_class} #{@unfound_key} was not found"
        next
      end
      puts "Time10 elapsed #{(Time.now - start_time)*1000} milliseconds"
      start_time = Time.now
      # translate unique_attr if it's a custom field -- only on the first issue
      if !unique_attr_checked
        if unique_field && !ISSUE_ATTRS.include?(unique_attr.to_sym)
          issue.available_custom_fields.each do |cf|
            if cf.name == unique_attr
              unique_attr = "cf_#{cf.id}"
              break
            end
          end
        end
        unique_attr_checked = true
      end
      puts "Time11 elapsed #{(Time.now - start_time)*1000} milliseconds"
      start_time = Time.now
      if update_issue
        begin
          issue = issue_for_unique_attr(unique_attr,row[unique_field],row)

          # ignore other project's issue or not
          if issue.project_id != @project.id && !update_other_project
            @skip_count += 1
            next
          end

          # ignore closed issue except reopen
          if issue.status.is_closed?
            if status == nil || status.is_closed?
              @skip_count += 1
              next
            end
          end

          # init journal
          # note = row[journal_field] || ''
          # journal = issue.init_journal(author || User.current,
          #   note || '')

          @update_count += 1

        rescue NoIssueForUniqueValue
          if ignore_non_exist
            @skip_count += 1
            next
          else
            @failed_count += 1
            @failed_issues[@failed_count] = row
            @messages << "Warning: Could not update issue #{@failed_count} below, no match for the value #{row[unique_field]} were found"
            next
          end

        rescue MultipleIssuesForUniqueValue
          @failed_count += 1
          @failed_issues[@failed_count] = row
          @messages << "Warning: Could not update issue #{@failed_count} below, multiple matches for the value #{row[unique_field]} were found"
          next
        end
      end
      puts "Time12 elapsed #{(Time.now - start_time)*1000} milliseconds"
      start_time = Time.now
      # project affect
      if project == nil
        project = Project.find_by_id(issue.project_id)
      end
      @affect_projects_issues.has_key?(project.name) ?
        @affect_projects_issues[project.name] += 1 : @affect_projects_issues[project.name] = 1

      # required attributes
      issue.status_id = status != nil ? status.id : issue.status_id
      issue.priority_id = priority != nil ? priority.id : issue.priority_id

      subj = row[attrs_map["subject"]].present? ? row[attrs_map["subject"]].gsub(/"|'/,'') : nil
      desc = row[attrs_map["description"]].present? ? row[attrs_map["description"]].gsub(/"|'/,'') : nil

      issue.subject = subj || issue.subject
      issue.description = desc || issue.description
      issue.category_id = category != nil ? category.id : issue.category_id
      issue.start_date = row[attrs_map["start_date"]].blank? ? nil : Date.parse(row[attrs_map["start_date"]])
      issue.due_date = row[attrs_map["due_date"]].blank? ? nil : Date.parse(row[attrs_map["due_date"]])
      issue.assigned_to_id = assigned_to != nil ? assigned_to.id : issue.assigned_to_id
      issue.fixed_version_id = fixed_version_id != nil ? fixed_version_id : issue.fixed_version_id
      issue.done_ratio = row[attrs_map["done_ratio"]] || issue.done_ratio
      issue.estimated_hours = row[attrs_map["estimated_hours"]] || issue.estimated_hours
      # issue.root_id = row[attrs_map["root_id"]]

      # issue.created_on = Time.now
      # issue.updated_on = Time.now
      p '---- max -----'
      p row[attrs_map["root_id"]]
      puts "Time13 elapsed #{(Time.now - start_time)*1000} milliseconds"
      start_time = Time.now
      # parent issues
      begin
        parent_value = row[attrs_map["parent_issue"]]
        if parent_value && (parent_value.length > 0)
          issue.parent_issue_id = issue_for_unique_attr(unique_attr,parent_value,row).id
          issue.parent_id=issue_for_unique_attr(unique_attr,parent_value,row).id
        end
      rescue NoIssueForUniqueValue
        if ignore_non_exist
          @skip_count += 1
        else
          @failed_count += 1
          @failed_issues[@failed_count] = row
          @messages << "Warning: When setting the parent for issue #{@failed_count} below, no matches for the value #{parent_value} were found"
          next
        end
      rescue MultipleIssuesForUniqueValue
        @failed_count += 1
        @failed_issues[@failed_count] = row
        @messages << "Warning: When setting the parent for issue #{@failed_count} below, multiple matches for the value #{parent_value} were found"
        next
      end
      puts "Time14 elapsed #{(Time.now - start_time)*1000} milliseconds"
      start_time = Time.now
      # custom fields
      custom_failed_count = 0
      issue.custom_field_values = issue.available_custom_fields.inject({}) do |h, cf|
        if value = row[attrs_map[cf.name]].blank? ? nil : row[attrs_map[cf.name]]
          begin
            if cf.field_format == 'user'
              value = user_id_for_login!(value).to_s
            elsif cf.field_format == 'version'
              value = version_id_for_name!(project,value,add_versions).to_s
            elsif cf.field_format == 'date'
              value = value.to_date.to_s(:db)
            end
            h[cf.id] = value
          rescue
            if custom_failed_count == 0
              custom_failed_count += 1
              @failed_count += 1
              @failed_issues[@failed_count] = row
            end
            @messages << "Warning: When trying to set custom field #{cf.name} on issue #{@failed_count} below, value #{value} was invalid"
          end
        end
        h
      end
      puts "Time15 elapsed #{(Time.now - start_time)*1000} milliseconds"
      start_time = Time.now
      next if custom_failed_count > 0

      # watchers
      watcher_failed_count = 0
      if watchers
        addable_watcher_users = issue.addable_watcher_users
        watchers.split(',').each do |watcher|
          begin
            watcher_user = user_id_for_login!(watcher)
            if issue.watcher_users.include?(watcher_user)
              next
            end
            if addable_watcher_users.include?(watcher_user)
              issue.add_watcher(watcher_user)
            end
          rescue ActiveRecord::RecordNotFound
            if watcher_failed_count == 0
              @failed_count += 1
              @failed_issues[@failed_count] = row
            end
            watcher_failed_count += 1
            @messages << "Warning: When trying to add watchers on issue #{@failed_count} below, User #{watcher} was not found"
          end
        end
      end
      next if watcher_failed_count > 0
      puts "Time16 elapsed #{(Time.now - start_time)*1000} milliseconds"
      start_time = Time.now

      unless issue.valid?
        @failed_count += 1
        @failed_issues[@failed_count] = row
        @messages << "Warning: The following data-validation errors occurred on issue #{@failed_count} in the list below"
        issue.errors.each do |attr, error_message|
          @messages << "Error: #{attr} #{error_message}"
        end
      else
        sql_values=""
        if !issue.id.present?
          issue.created_on = Time.now
        end
        issue.updated_on = Time.now
        @saved_issues_attributes = issue.attributes.keys.*','
        saved_issues_values = issue.attributes.values
        sql_values = sql_values + "(#{ saved_issues_values.map{ |i| '"%s"' % i }.join(', ') }),"
        sql_values=sql_values.chomp(',')
        sql_query= "VALUES#{sql_values}"
        p final_sql = "REPLACE INTO issues (#{@saved_issues_attributes}) #{sql_query}"
        connection = ActiveRecord::Base.connection
        connection.execute(final_sql.to_s)
        if issue.id.present?

          # sql_query_for_parent="UPDATE issues set root_id=#{issue.id},parent_id=#{issue.parent_id.present? && issue.parent_id !=0 ? issue.parent_id : "NULL"},lft=#{Issue.maximum(:lft) + 1},rgt=#{Issue.maximum(:rgt) + 1}  where id = #{issue.id}"
          # connection.execute(sql_query_for_parent.to_s)
          issue.self_parent_update
        else

          sql_for_inserted_id="SELECT LAST_INSERT_ID() from issues LIMIT 1"
          find_inserted_record =connection.execute(sql_for_inserted_id)
          if find_inserted_record.present? && find_inserted_record.first[0] != 0
            issue = Issue.find(find_inserted_record.first[0])

            # if issue.parent_id.present? && issue.parent_id != 0
            #
            #   # issue.self_parent_update
            #   parent = Issue.find(issue.parent_id)
            #   if parent.present?
            #
            #     Issue.where(id: issue.id).update_all(:parent_id=>parent.root_id,:root_id=>parent.root_id,:lft=>parent.rgt+0,:rgt=>parent.rgt+1)
            #     updated_issue = Issue.find(issue.id)
            #     Issue.where(id: parent.id).update_all(:root_id=>parent.root_id,:rgt=>updated_issue.rgt+1)
            #
            #   end
            #
            # else
            #   Issue.where(id: issue.id).update_all(:root_id=>issue.id,:parent_id=>"NULL",:lft=>Issue.maximum(:lft) + 1,:rgt=>Issue.maximum(:rgt) + 1  )
            #
            # end

            # sql_query_for_parent="UPDATE issues set root_id=#{issue.id},parent_id=#{issue.parent_id.present? && issue.parent_id !=0 ? issue.parent_id : "NULL"},lft=#{Issue.maximum(:lft) + 1},rgt=#{Issue.maximum(:rgt) + 1}  where id = #{issue.id}"
            # connection.execute(sql_query_for_parent.to_s)
           if issue.parent_id.present? && issue.parent_id !=0
            issue.self_parent_update

           else
             Issue.where(id: issue.id).update_all(:root_id=>issue.id,:parent_id=>nil,:lft=>Issue.maximum(:lft) + 1,:rgt=>Issue.maximum(:lft) + 2  )
           end

          end
        end

        if unique_field
          @issue_by_unique_attr[row[unique_field]] = issue
        end
        begin
          IssueRelation::TYPES.each_pair do |rtype, rinfo|
            if !row[attrs_map[rtype]]
              next
            end
            other_issue = issue_for_unique_attr(unique_attr,row[attrs_map[rtype]],row)
            relations = issue.relations.select { |r| (r.other_issue(issue).id == other_issue.id) && (r.relation_type_for(issue) == rtype) }
            p '----- relation -----'
            if relations.length == 0
              relation = IssueRelation.new( :issue_from => issue, :issue_to => other_issue, :relation_type => rtype )
            end
          end
        rescue NoIssueForUniqueValue
          if ignore_non_exist
            @skip_count += 1
            next
          end
        rescue MultipleIssuesForUniqueValue
          break
        end
        @handle_count += 1
      end
      puts "Time17 elapsed #{(Time.now - start_time)*1000} milliseconds"
      # start_time = Time.now
    end # do

    if @failed_issues.size > 0
      @failed_issues = @failed_issues.sort
      @headers = @failed_issues[0][1].headers
    end

    # Clean up after ourselves
    iip.delete
    # Garbage prevention: clean up iips older than 3 days
    ImportInProgress.delete_all(["created < ?",Time.new - 3*24*60*60])
    puts "Time18 elapsed #{(Time.now - first_start_time)*1000} milliseconds"
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
