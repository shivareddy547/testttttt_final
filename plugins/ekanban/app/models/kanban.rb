class Kanban < ActiveRecord::Base
  unloadable

  belongs_to  :project
  belongs_to  :tracker
  belongs_to  :creater, :foreign_key => :created_by, :class_name => :User
  has_many  :kanban_pane, :order => "position ASC"
  validates_presence_of  :project_id, :tracker_id
  serialize :card_selected_display_columns,Array
  serialize :card_selected_tooltip_columns,Array
  # serialize :tracker_id,Array

  before_destroy :delete_all_members

  #scope :by_project_tracker, lambda{ |project,tracker| {:conditions => ["#{Kanban.table_name}.project_id = #{project} and #{Kanban.table_name}.tracker_id = #{tracker_id}"]}}
  scope :by_project, lambda {|project|
  	project_id = project.nil? ? Project.current : project.is_a?(Project) ? project.id : project.to_i
  	where(:project_id => project_id)
  }
  scope :by_tracker, lambda {|tracker| where(:tracker_id => tracker)}
  scope :valid, lambda {where(:is_valid => true)}

  def self.to_id(kanban)
    kanban_id = kanban.nil? ? nil : kanban.is_a?(Kanban) ? kanban.id : kanban.to_i
  end

  def self.to_kanban(kanban)
    kanban = kanban.nil? ? nil : kanban.is_a?(kanban) ? kanban : kanban.find(kanban)
  end

  def self.statement(filters)
    # filters clauses
    filters_clauses = []
    filters.each_key do |field|
      next if field == "subproject_id"
      v = values_for(field).clone
      next unless v and !v.empty?
      operator = operator_for(field)

      # "me" value substitution
      if %w(assigned_to_id author_id user_id watcher_id).include?(field)
        if v.delete("me")
          if User.current.logged?
            v.push(User.current.id.to_s)
            v += User.current.group_ids.map(&:to_s) if field == 'assigned_to_id'
          else
            v.push("0")
          end
        end
      end

      if field == 'project_id'
        if v.delete('mine')
          v += User.current.memberships.map(&:project_id).map(&:to_s)
        end
      end

      if field =~ /cf_(\d+)$/
        # custom field
        filters_clauses << sql_for_custom_field(field, operator, v, $1)
      elsif respond_to?("sql_for_#{field}_field")
        # specific statement
        filters_clauses << send("sql_for_#{field}_field", field, operator, v)
      else
        # regular field
        filters_clauses << '(' + sql_for_field(field, operator, v, queried_table_name, field) + ')'
      end
    end if filters

    if (c = group_by_column) && c.is_a?(QueryCustomFieldColumn)
      # Excludes results for which the grouped custom field is not visible
      filters_clauses << c.custom_field.visibility_by_project_condition
    end

    filters_clauses << project_statement
    filters_clauses.reject!(&:blank?)

    filters_clauses.any? ? filters_clauses.join(' AND ') : nil
  end
  def values_for(field)
    has_filter?(field) ? filters[field][:values] : nil
  end
  def self.values_for(field)
    has_filter?(field) ? filters[field][:values] : nil
  end

end


