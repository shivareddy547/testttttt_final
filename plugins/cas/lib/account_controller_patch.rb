module AccountControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
      # Issues Bulk update with out Activities updation

      # prevents login action to be filtered by check_if_login_required application scope filter
      skip_before_filter :check_if_login_required, :check_password_change

      ######################### CAS #################################

      before_filter CASClient::Frameworks::Rails::GatewayFilter, :except => :index

      # This requires the user to be authenticated for viewing allother pages.
      before_filter CASClient::Frameworks::Rails::Filter, :except => :index
      #skip_before_filter :cas_filter, :only => :index

      def index
        @username = session[:cas_user]
        @login_url = CASClient::Frameworks::Rails::Filter.login_url(self)
      end

      def my_account
        @username = session[:cas_user]

        # Additional user attributes are available if your
        # CAS server is configured to provide them.
        # See http://code.google.com/p/rubycas-server/wiki/HowToSendExtraUserAttributes
        @extra_attributes = session[:cas_extra_attributes]
      end

      def logout
        CASClient::Frameworks::Rails::Filter.logout(self)
      end

      ################# CAS END #########################################
      # for CAS purpuse need to command this logout action
      # Log out current user and redirect to welcome page
      # def logout
      #   if User.current.anonymous?
      #     redirect_to home_url
      #   elsif request.post?
      #     logout_user
      #     redirect_to home_url
      #   end
      #   # display the logout form
      # end


      # Login request and validation
      def login
        if request.get?
          if User.current.logged?
            redirect_to home_url
          end
        else
          authenticate_user
        end
      rescue AuthSourceException => e
        logger.error "An error occured when authenticating #{params[:username]}: #{e.message}"
        render_error :message => e.message
      end



    end
  end
end
