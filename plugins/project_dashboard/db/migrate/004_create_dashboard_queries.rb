class CreateDashboardQueries < ActiveRecord::Migration
  def self.up
    create_table :dashboard_queries, :force => true do |t|
      t.column "project_id", :integer
      t.column "name", :string
      t.column "filters", :text
      t.column "user_id", :integer
      t.column "is_public", :boolean
      t.column "column_names", :text
      t.column "sort_criteria", :text
      t.column "group_by", :string
      t.column "type", :string
      t.column "visibility", :integer
      t.column "options", :text

    end
  end

  def self.down
    drop_table :dashboard_queries
  end
end
