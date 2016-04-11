# include DashboardHelper
require_dependency 'attachments_controller'
module AttachmentsControllerPatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.class_eval do
      before_filter :file_readable, :read_authorize, :only => [:show]
      skip_before_filter :delete_authorize, :only => :destroy
      unloadable
      # helper :search

      # include SearchHelper
      # Insert overrides here, for example:


      #alias_method_chain :show, :plugin # This tells Redmine to allow me to extend show by letting me call it via "show_without_plugin" above.
      # I can outright override it by just calling it "def show", at which case the original controller's method will be overridden instead of extended.
    end
  end

  module InstanceMethods
    # Here, I include helper like this (I've noticed how the other controllers do it)
    # helper :queries
    include ApplicationHelper

    def index_with_filters
      # ...
      # do stuff
      # ...
    end
  end # module
  end


