class RenameColumnsAndAddIssueSlaToIssue < ActiveRecord::Migration
  def change
    add_column :issues, :issue_sla, :float
    add_column :issues, :response, :boolean, :default => false
    rename_column :issues, :update_by_manager_date, :first_response_date

    Issue.where("expiration_date is not null").each do |i| 
    	i.update_attributes(:issue_sla => (i.expiration_date - i.created_on)/3600)
    end
  end

end