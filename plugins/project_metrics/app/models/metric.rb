class Metric < ActiveRecord::Base
  unloadable
  include ApplicationHelper

  def self.query_to_excel(items, query, options={})
    book        = Spreadsheet::Workbook.new
    spreadsheet = StringIO.new
    encoding    = l(:general_csv_encoding)
    columns     = query.available_inline_columns
    query.available_block_columns.each do |column|
      if options[column.name].present?
        columns << column
      end
    end

    export =  book.create_worksheet
    export.row(0).concat []#%w{Name Country Acknowlegement}
      # xls header fields
    export.row(0).concat columns.collect {|c| Redmine::CodesetUtil.from_utf8(c.caption.to_s, encoding) }
      # xls lines

      items.each_with_index do |item, i|
        export.row(i+1).concat columns.collect {|c| Redmine::CodesetUtil.from_utf8(Metric.csv_content(c, item), encoding) }
      end
    book.write spreadsheet
    return spreadsheet.string

  end

 def self.query_to_excelx(items, query, options={},project_identifier,role_for_xl)

    spreadsheet = StringIO.new
    encoding    = l(:general_csv_encoding)
    columns     = query.available_inline_columns
    query.available_block_columns.each do |column|
      if options[column.name].present?
        columns << column
      end
    end

    @project = Project.find_by_identifier(project_identifier)
    time_log_items = TimeEntry.where(:issue_id=>items.map(&:id))
    t_query = TimeEntryQuery.new
    t_query.project_id=@project.id
    time_log_columns = t_query.available_columns
    array_for_time_log = time_log_columns.collect {|c| Redmine::CodesetUtil.from_utf8(c.caption.to_s, encoding) }

    array_for_time_log.unshift("Subject")
    array_for_time_log.unshift("IssueID")



    if role_for_xl == "Manager"
     path  = File.join(Rails.root, "/plugins/project_metrics/download/manager/#{project_identifier}.xlsx")
    # path  = File.join(Rails.root, '/plugins/project_metrics/download/index1.xlsx')
    # path1  = File.join(Rails.root, '/plugins/project_metrics/download/metrics3.xlsx')
    begin
      workbook = RubyXL::Parser.parse(path)
    rescue
      path  = File.join(Rails.root, "/plugins/project_metrics/download/manager/metrics.xlsx")
      workbook = RubyXL::Parser.parse(path)
    end
    elsif role_for_xl == "Senior Manager"

      path  = File.join(Rails.root, "/plugins/project_metrics/download/smanager/#{project_identifier}.xlsx")
      begin
         workbook = RubyXL::Parser.parse(path)
      rescue
        path  = File.join(Rails.root, "/plugins/project_metrics/download/smanager/SrMgmt4_V1.0.xlsx")
        workbook = RubyXL::Parser.parse(path)
      end
    elsif role_for_xl == "Inia Observation"
            path  = File.join(Rails.root, "/plugins/project_metrics/download/iniaobservation/#{project_identifier}.xlsx")
             begin
              workbook = RubyXL::Parser.parse(path)
            rescue
               path  = File.join(Rails.root, "/plugins/project_metrics/download/iniaobservation/iNia_observation_updated_V1.0.xlsx")
            workbook = RubyXL::Parser.parse(path)
        end
    elsif role_for_xl == "Resource Measurements"
      path  = File.join(Rails.root, "/plugins/project_metrics/download/resourcemeasure/resource_measure.xlsx")
      begin
        workbook = RubyXL::Parser.parse(path)
      rescue
        # path  = File.join(Rails.root, "/plugins/project_metrics/download/iniaobservation/iNia_observation_updated_V1.0.xlsx")
        workbook = RubyXL::Parser.parse(path)
      end


    end

    # sheet2 = workbook.add_worksheet('Data')
    sheet2 = workbook.worksheets.first

    issue_data_types = Issue.columns.collect { |c|  c.type }
    # issue_data_types = issue_data_types[0]
    array = columns.collect {|c| Redmine::CodesetUtil.from_utf8(c.caption.to_s, encoding) }
    array1 = array
    array.each_with_index do  |item, i|
      sheet2.insert_cell(0, i, "#{item}")
    end



    # Time log excel sheet

    if role_for_xl == "Resource Measurements"
    sheet3 = workbook.worksheets.last
    time_log_array = time_log_columns.collect {|c| Redmine::CodesetUtil.from_utf8(c.caption.to_s, encoding) }
    # array1 = array
    time_log_array.unshift("IssueId")
    time_log_array.unshift("Subject")
    time_log_array.unshift("Tracker")
    time_log_array.each_with_index do  |item, i|
      sheet3.insert_cell(0, i, "#{item}")
    end
    time_log_items.each_with_index do |item, i|
     time_log_array1 = time_log_columns.collect {|c|
        converted_value = Redmine::CodesetUtil.from_utf8(Metric.csv_content(c, item), encoding)
        # if array[i] == "Estimated time"
        #   Float(converted_value)
        # elsif array[i] == "Spent time"
        #   Float(converted_value)
        # elsif array[i] == "% Done"
        #   Integer(converted_value)
        # else
        #   converted_value
        # end
      }
      time_log_array1.unshift("#{item.issue.id}")
      time_log_array1.unshift("#{item.issue.subject}")
     time_log_array1.unshift("#{item.issue.tracker.name}")
      time_log_array1.each_with_index do  |item, j|
        sheet3.insert_cell(i+1, j, "#{item}")
      end
    end

    end

    items.each_with_index do |item, i|
      array = columns.collect {|c|
       converted_value = Redmine::CodesetUtil.from_utf8(Metric.csv_content(c, item), encoding)
        if array[i] == "Estimated time"
          Float(converted_value)
         elsif array[i] == "Spent time"
          Float(converted_value)
        elsif array[i] == "% Done"
          Integer(converted_value)
        else
          converted_value
         end
      }
   array.each_with_index do  |item, j|
       if array1[j] == "Estimated time"
            sheet2.insert_cell(i+1, j, Float(item)) rescue item
          # Float(converted_value)

        elsif array1[j] == "Spent time"
            sheet2.insert_cell(i+1, j, Float(item)) rescue item
        elsif array1[j] == "% Done"
            sheet2.insert_cell(i+1, j, Integer(item)) rescue item
        elsif array1[j] == "#"
          sheet2.insert_cell(i+1, j, Integer(item)) rescue item
        elsif array1[j] == "Start date"
          sheet2.insert_cell(i+1, j, item.to_datetime) rescue item
        elsif array1[j] == "Due date"
          sheet2.insert_cell(i+1, j, item.to_datetime) rescue item
        elsif array1[j] == "Updated"
          sheet2.insert_cell(i+1, j, item.to_datetime) rescue item
        elsif array1[j] == "Updated"
          sheet2.insert_cell(i+1, j, item.to_datetime) rescue item
        else
         sheet2.insert_cell(i+1, j, "#{item}")
        end
      end
      # export.row(i+1).concat columns.collect {|c| Redmine::CodesetUtil.from_utf8(Metric.csv_content(c, item), encoding) }
    end
    return workbook.stream.string
  end




  def self.csv_content(column, issue)
    # !column.name.to_s.split(":").last.include?("cf_")
    value = column.value(issue)
    if value.is_a?(Array)
      value.collect {|v| csv_value(column, issue, v)}.compact.join(', ')
    else
      Metric.csv_value(column, issue, value)
    end
  end

  def self.csv_value(column, issue, value)
    case value.class.name
      when 'Time'
        format_time(value)
      when 'Date'
        format_date(value)
      when 'Float'
        sprintf("%.2f", value).gsub('.', l(:general_csv_decimal_separator))
      when 'IssueRelation'
        other = value.other_issue(issue)
        l(value.label_for(issue)) + " ##{other.id}"
      else
        value.to_s
    end
  end


  def self.get_issues_for_excel
    spreadsheet = StringIO.new
    encoding    = l(:general_csv_encoding)
   @project = Project.find_by_identifier('dmo')
   # @child_projects = @project.children
   start_date=(Date.today-3).at_beginning_of_week
   end_date=start_date.at_end_of_week-2
   @find_target_version = Sprints.where(:project_id=>@project.id,:ir_start_date=> start_date,:ir_end_date=> end_date).last
   # departments = CustomField.find_by_sql("select possible_values from custom_fields where name='department'").last.possible_values
    # directory_name =  File.join(Rails.root, "/home/dgoadmin/Dropbox/#{@find_target_version.name}_#{@find_target_version.ir_start_date}_to_#{@find_target_version.ir_end_date}")
   if @find_target_version.present?
   directory_name = "/home/dgoadmin/Dropbox/DU.DAO/#{@find_target_version.name}"
    Dir.mkdir(directory_name) unless File.exists?(directory_name)
    @issue_query = IssueQuery.new
    @issue_query.project_id=@project.id
    issues_columns = @issue_query.available_columns

    path  = File.join(Rails.root, "/plugins/project_metrics/download/dmo/DMO_Weekly_Report.xlsx")
    workbook = RubyXL::Parser.parse(path)
    issue_ids = Issue.find_by_sql("select i.id from issues i join custom_values cv on cv.customized_id=i.id
    where cv.customized_type='issue' and cv.custom_field_id=(select id from custom_fields where name='department' ) and fixed_version_id=#{@find_target_version.id}")
    if issue_ids.present?
      time_log_items = Issue.where(:id=> issue_ids)
      array_for_issue_log = issues_columns.collect {|c| Redmine::CodesetUtil.from_utf8(c.caption.to_s, encoding) }
      sheet3 = workbook.worksheets.last
      time_log_array = issues_columns.collect {|c| Redmine::CodesetUtil.from_utf8(c.caption.to_s, encoding) }
      # array1 = array
      time_log_array.each_with_index do  |item, i|
        if item == "Estimated time"
        
        end 

        sheet3.insert_cell(0, i, "#{item}")
      end
      time_log_items.each_with_index do |item, i|
        time_log_array1 = issues_columns.collect {|c|
          converted_value = Redmine::CodesetUtil.from_utf8(Metric.csv_content(c, item), encoding)
          # if array[i] == "Estimated time"
          #   Float(converted_value)
          # elsif array[i] == "Spent time"
          #   Float(converted_value)
          # elsif array[i] == "% Done"
          #   Integer(converted_value)
          # else
          #   converted_value
          # end
        }
        # time_log_array1.unshift("#{item.issue.id}")
        # time_log_array1.unshift("#{item.issue.subject}")
        # time_log_array1.unshift("#{item.issue.tracker.name}")
        time_log_array1.each_with_index do  |item, j|
          sheet3.insert_cell(i+1, j, "#{item}")
        end
# p "++++++++++++++++sheet locaked++++++++++="
#         sheet3.apply_protection
#         sheet3.protection.locked
#         p "++++++++===end ++++"
      end


    end
    path  = "/home/dgoadmin/Dropbox/DU.DAO/#{@find_target_version.name}/DMO_Weekly_Report.xlsx"
     workbook.write(path)
else

  p "++++++Target Version Not found for #{start_date} and #{end_date}"

   end


    # departments.each_with_index do |each_department,index|
    #
    #   # return workbook.stream.string
    # end

  end



end
