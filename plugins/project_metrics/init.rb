# encoding: UTF-8
require 'redmine'
Mime::Type.register "application/xls", :xls


RedmineApp::Application.config.after_initialize do
  require_dependency 'project_metrics/infectors'
end



Redmine::Plugin.register :project_metrics do
  name 'Project Metrics plugin'
  author 'OFS'
  description 'This is a plugin for Redmine'
  version '0.0.1'

  project_module :metrics do
    permission :metrics, :metrics => :index
  end
  menu :project_menu, :metrics, { :controller => 'metrics', :action => 'index' }, :caption => :label_metrics, :before => :settings, :param => :project_id
end


Rails.configuration.to_prepare do
  require 'rufus/scheduler'
  scheduler = Rufus::Scheduler.new
  time="0 14 * * 1"
  # time="*/5 * * * *"
  scheduler.cron time do
    begin
      Rails.logger.info "==========Scheduler Started=========="
      p 111111111111111111111
      Metric.get_issues_for_excel
    rescue Exception => e
      Rails.logger.info "Scheduler failed: #{e.message}"
    end
  end

  # scheduler.every '1s' do
  #   puts "change the oil filter!"
  # end

end
