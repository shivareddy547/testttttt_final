module ApplicationControllerPatch
  def self.included(base)
    base.class_eval do
      before_filter :clear_session
      # Insert overrides here, for example:
      def clear_session

        if !(params[:controller] == "timelog_import" && (params[:action]=="export_csv" || params[:action]=="result" ))
          session[:failed_issues] = []
        end

      end
      end
      #alias_method_chain :show, :plugin # This tells Redmine to allow me to extend show by letting me call it via "show_without_plugin" above.
      # I can outright override it by just calling it "def show", at which case the original controller's method will be overridden instead of extended.
    end
  end


