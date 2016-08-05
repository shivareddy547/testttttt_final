module ApplicationHelperPatch1
  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)

    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development

      alias_method_chain :user_settings_tabs, :rate_tab
    end
  end

  module InstanceMethods
    # Adds a rates tab to the user administration page
    def get_closed_sprints(project)
      project.versions.where(:status=>'closed').map(&:id) if project.versions.present?
    end
  end
  1111111111
end