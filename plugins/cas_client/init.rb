require 'redmine'
require_dependency 'account_controller_patch'
require_dependency 'application_controller_patch'


AccountController.send(:include, AccountControllerPatch)
ApplicationController.send(:include, ApplicationControllerPatch)

Redmine::Plugin.register :cas_client do
  name 'Cas Client plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'
end


RedmineApp::Application.config.before_initialize do
  cas_logger = CASClient::Logger.new('log/cas.log')
  cas_logger.level = Logger::DEBUG



  CASClient::Frameworks::Rails::Filter.configure(
      :cas_base_url  => "https://192.168.8.103:8443/cas/",
      :login_url     => "https://192.168.8.103:8443/cas/login",
      :logout_url    => "https://192.168.8.103:8443/cas/logout?service=http://192.168.4.74/",
      :username_session_key => :cas_user,
      :extra_attributes_session_key => :cas_extra_attributes,
      :logger => cas_logger,
      :enable_single_sign_out => true,
      :service_url => "http://192.168.4.74/"
  )
  end