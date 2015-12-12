class WikiRoles < ActiveRecord::Base
  unloadable
  belongs_to :wiki_page, :foreign_key => 'wiki_page_id'
  serialize :permissions, Array

  # safe_attributes 'role', 'role',
  #                 :if => lambda {|page, user| page.new_record? || user.allowed_to?(:rename_wiki_pages, page.project)}
  # safe_attributes 'permissions', 'permissions',
  #                 :if => lambda {|page, user| page.new_record? || user.allowed_to?(:rename_wiki_pages, page.project)}
end
