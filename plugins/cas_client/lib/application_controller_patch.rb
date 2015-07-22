module ApplicationControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
      # Issues Bulk update with out Activities updation
      before_filter :update_cas_configuration
      before_filter CASClient::Frameworks::Rails::Filter

      def update_cas_configuration
         root_url = request.fullpath
        if !root_url.include?('ticket=')
          url = "http://#{request.host_with_port}#{root_url}"
          CASClient::Frameworks::Rails::Filter.configure(
              :cas_base_url  => "https://192.168.8.103:8443/cas",
              :authenticate_on_every_request=>true,
              :service_url => url
          )

        end
      end

      def find_current_user
        p 111111111111111111111111111111111111111111111111111111111111111
        user = nil
        unless api_request?
          if session[:user_id]
            # existing session
            user = (User.active.find(session[:user_id]) rescue nil)
          elsif session[:cas_user].present?
            user = User.active.find_by_login(session[:cas_user]) rescue nil
          elsif autologin_user = try_to_autologin
            user = autologin_user
          elsif params[:format] == 'atom' && params[:key] && request.get? && accept_rss_auth?
            # RSS key authentication does not start a session
            user = User.find_by_rss_key(params[:key])
          end
        end
        if user.nil? && Setting.rest_api_enabled? && accept_api_auth?
          if (key = api_key_from_request)
            # Use API key
            user = User.find_by_api_key(key)
          elsif request.authorization.to_s =~ /\ABasic /i
            # HTTP Basic, either username/password or API key/random
            authenticate_with_http_basic do |username, password|
              user = User.try_to_login(username, password) || User.find_by_api_key(username)
            end
            if user && user.must_change_password?
              render_error :message => 'You must change your password', :status => 403
              return
            end
          end
          # Switch user if requested by an admin user
          if user && user.admin? && (username = api_switch_user_from_request)
            su = User.find_by_login(username)
            if su && su.active?
              logger.info("  User switched by: #{user.login} (id=#{user.id})") if logger
              user = su
            else
              render_error :message => 'Invalid X-Redmine-Switch-User header', :status => 412
            end
          end
        end
        user
      end

    end
    end
end
