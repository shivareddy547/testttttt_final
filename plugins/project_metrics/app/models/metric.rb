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
    elsif role_for_xl == "SeniorManager"

      path  = File.join(Rails.root, "/plugins/project_metrics/download/smanager/#{project_identifier}.xlsx")
      begin
         workbook = RubyXL::Parser.parse(path)
      rescue
        path  = File.join(Rails.root, "/plugins/project_metrics/download/smanager/SrMgmt4_V1.0.xlsx")
        workbook = RubyXL::Parser.parse(path)
      end
    elsif role_for_xl == "IniaObservation"
            path  = File.join(Rails.root, "/plugins/project_metrics/download/iniaobservation/#{project_identifier}.xlsx")
             begin
              workbook = RubyXL::Parser.parse(path)
            rescue
               path  = File.join(Rails.root, "/plugins/project_metrics/download/iniaobservation/iNia_observation_updated_V1.0.xlsx")
            workbook = RubyXL::Parser.parse(path)
        end

    end

    # sheet2 = workbook.add_worksheet('Data')
    sheet2 = workbook.worksheets.last
    issue_data_types = Issue.columns.collect { |c|  c.type }
    # issue_data_types = issue_data_types[0]
    array = columns.collect {|c| Redmine::CodesetUtil.from_utf8(c.caption.to_s, encoding) }
    array1 = array
    array.each_with_index do  |item, i|
      sheet2.insert_cell(0, i, "#{item}")
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


end
