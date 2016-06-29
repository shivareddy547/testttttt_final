module SettingsControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
      def plugin
        @plugin = Redmine::Plugin.find(params[:id])
        unless @plugin.configurable?
          render_404
          return
        end


p "+++++++++++++++=settings +++++++++++++"
        p params[:settings]
        if request.post?
          Setting.send "plugin_#{@plugin.id}=", params[:settings]
 if Setting.send "plugin_#{@plugin.id}=", params[:settings]

params[:settings][:wktime_public_holiday].each do |each_day|
p 33333333333333
p each_day.split('|')[0]
# p values = each_day.split('|')[0].spilt(',')
 public_holiday = PublicHolyday.find_or_initialize_by_date_and_location(each_day.split('|')[0],each_day.split('|')[2])
 public_holiday.save
p 888888888888888888888


end

 end

          wktime_helper = Object.new.extend(WktimeHelper)
          #wktime_helper.sendNonLogTimeMail()
          #wktime_helper.lock_unlock_users()
          flash[:notice] = l(:notice_successful_update)
          redirect_to plugin_settings_path(@plugin)
        else
          @partial = @plugin.settings[:partial]
          @settings = Setting.send "plugin_#{@plugin.id}"
        end
      rescue Redmine::PluginNotFound
        render_404
      end
      end
      #alias_method_chain :show, :plugin # This tells Redmine to allow me to extend show by letting me call it via "show_without_plugin" above.
      # I can outright override it by just calling it "def show", at which case the original controller's method will be overridden instead of extended.
    end
  end


