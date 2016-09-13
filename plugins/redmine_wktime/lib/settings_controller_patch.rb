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
     if request.post?
       Setting.send "plugin_#{@plugin.id}=", params[:settings]
     if Setting.send "plugin_#{@plugin.id}=", params[:settings]

         params[:settings][:wktime_public_holiday].each do |each_day|
        # p values = each_day.split('|')[0].spilt(',')
         public_holiday = PublicHolyday.find_or_initialize_by_date_and_location(each_day.split('|')[0],each_day.split('|')[2])
         public_holiday.save

          end
        end
         wktime_helper = Object.new.extend(WktimeHelper)
          #wktime_helper.sendNonLogTimeMail()
          #wktime_helper.lock_unlock_users()
          update_schedules
          flash[:notice] = l(:notice_successful_update)
          redirect_to plugin_settings_path(@plugin)
        else
          @partial = @plugin.settings[:partial]
          @settings = Setting.send "plugin_#{@plugin.id}"
        end
      rescue Redmine::PluginNotFound
        render_404
      end

      def update_schedules
        require 'rufus/scheduler'
        # Employee timeentry nc creation.

        scheduler1 = Rufus::Scheduler.new
        # submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
        day = Setting.plugin_redmine_wktime['wktime_nonlog_day']
        hr = Setting.plugin_redmine_wktime['wktime_nonlog_hr']
        min = Setting.plugin_redmine_wktime['wktime_nonlog_min']
        #changed from start_new to new to make compatible with latest version rufus scheduler 3.0.3
        if day.present? && hr.present? && min.present?
          if hr == '0' && min == '0'
            cronSt = "0 * * * *"
          else
            cronSt = "#{min} #{hr} * * *"
          end
          # cronSt= "45 23 * * *"
          scheduler1.cron cronSt do

            wktime_helper = Object.new.extend(WktimeHelper)
            wktime_helper.create_nc_for_employee_within_sla(Date.today-day.to_i)
            # wktime_helper.expire_unlock_history

          end

        end


        # L1 approval nc creation


        scheduler2 = Rufus::Scheduler.new
        # submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
        day = Setting.plugin_redmine_wktime['wktime_nonapprove_day_l1']
        hr = Setting.plugin_redmine_wktime['wktime_nonapprove_hr_l1']
        min = Setting.plugin_redmine_wktime['wktime_nonapprove_min_l1']
        #changed from start_new to new to make compatible with latest version rufus scheduler 3.0.3
        if day.present? && hr.present? && min.present?
          if hr == '0' && min == '0'
            cronSt = "0 * * * *"
          else
            cronSt = "#{min} #{hr} * * *"
          end
          # cronSt= "12 19 * * *"
          scheduler2.cron cronSt do

            wktime_helper = Object.new.extend(WktimeHelper)
            # wktime_helper.expire_unlock_history
            wktime_helper.create_nc_for_l1_within_sla(Date.today-day.to_i)
            # wktime_helper = Object.new.extend(WktimeHelper)
            wktime_helper.create_nc_for_l1_within_unlock_sla(Date.today-day.to_i)
            # wktime_helper.expire_unlock_history
            # wktime_helper.weekly_approve_l1_notifications(Date.today)

          end
        end


        #L2 approval nc creation


        scheduler3 = Rufus::Scheduler.new
        # submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
        day = Setting.plugin_redmine_wktime['wktime_nonapprove_day_l2']
        hr = Setting.plugin_redmine_wktime['wktime_nonapprove_hr_l2']
        min = Setting.plugin_redmine_wktime['wktime_nonapprove_min_l2']
        if day.present? && hr.present? && min.present?
          date = Date.parse(day)
          #changed from start_new to new to make compatible with latest version rufus scheduler 3.0.3
          if hr == '0' && min == '0'
            cronSt = "0 * * * *"
          else
            cronSt = "#{min} #{hr} * * #{date.wday}"
          end
          # cronSt= "45 23 * * *"
          scheduler3.cron cronSt do
            # wktime_helper = Object.new.extend(WktimeHelper)
            # wktime_helper.create_nc_for_l2_within_sla(Date.today)
            # wktime_helper.expire_unlock_history
            # wktime_helper.weekly_approve_l1_notifications(Date.today)


          end

        end

        # require 'rufus-scheduler'
        #
        # scheduler = Rufus::Scheduler.new
        #
        # scheduler.in '3s' do
        #   puts 'Hello... Rufus'
        # end
        scheduler4 = Rufus::Scheduler.new
        # submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
        day = Setting.plugin_redmine_wktime['wktime_nonapprove_day_l2']
        hr = Setting.plugin_redmine_wktime['wktime_nonapprove_hr_l2']
        min = Setting.plugin_redmine_wktime['wktime_nonapprove_min_l2']
        if day.present? && hr.present? && min.present?
          date = Date.parse(day)
          #changed from start_new to new to make compatible with latest version rufus scheduler 3.0.3
          if hr == '0' && min == '0'
            cronSt = "0 * * * *"
          else
            cronSt = "#{min} #{hr} * * #{date.wday}"
          end
          scheduler4 = Rufus::Scheduler.new
          # cronSt= "45 23 * * *"
          scheduler4.cron cronSt do
            wktime_helper = Object.new.extend(WktimeHelper)
            p "+++++++++++start l2 week +++ --- #{Time.now} "
            wktime_helper.create_nc_for_l2_within_sla(Date.today,"TEP_NC_016")
            wktime_helper.weekly_auto_approve(Date.today)
            p "+++++++++end +++"
            wktime_helper.expire_unlock_history
            # wktime_helper.weekly_approve_l2_notifications(Date.today)
            # wktime_helper.expire_unlock_history

          end

        end


        # scheduler.at '2014/12/24 2000' do
        #   puts "merry xmas!"
        # end
        # submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
        day = Setting.plugin_redmine_wktime['wktime_payroll_day']
        hr = Setting.plugin_redmine_wktime['wktime_payroll_hr']
        min = Setting.plugin_redmine_wktime['wktime_payroll_min']
        schedule5r = Rufus::Scheduler.new #changed from start_new to new to make compatible with latest version rufus scheduler 3.0.3

        if day.present? && hr.present? && min.present?
          if hr == '0' && min == '0'
            cronSt = "0 * * * *"
          else
            cronSt = "#{min} #{hr} * * *"
          end
          wktime_helper = Object.new.extend(WktimeHelper)
          # expire_time = wktime_helper.check_expire_date_payroll
          expire_time = UserUnlockEntry.pay_roll_deadline_final

          cronSt = "#{min} #{hr} * * #{(expire_time.to_date).wday}"
          # cronSt= "12 19 * * *"
          scheduler5.cron cronSt do
p "+++++monthly Payroll Approve start +++++++++++++++++"
            date_for_approve =  Date.new(Date.today.year, day.to_i, Date.today.month,day.to_i )
            wktime_helper.monthly_auto_approve(date_for_approve)
            # wktime_helper.create_nc_for_l1_within_sla(Date.today-day.to_i)
            # wktime_helper = Object.new.extend(WktimeHelper)
            # wktime_helper.create_nc_for_l1_within_unlock_sla(Date.today-day.to_i)
            # wktime_helper.expire_unlock_history
            # wktime_helper.weekly_approve_l1_notifications(Date.today)
p "+++++++++++end ++++++++++++++++++"
          end
        end

        scheduler6 = Rufus::Scheduler.new
        # scheduler.at '2014/12/24 2000' do
        #   puts "merry xmas!"
        # end
        # submissionDeadline = Setting.plugin_redmine_wktime['wktime_submission_deadline']
        day = Setting.plugin_redmine_wktime['wktime_payroll_day']
        hr = Setting.plugin_redmine_wktime['wktime_payroll_hr']
        min = Setting.plugin_redmine_wktime['wktime_payroll_min']
        if day.present? && hr.present? && min.present?
          #changed from start_new to new to make compatible with latest version rufus scheduler 3.0.3
          wktime_helper = Object.new.extend(WktimeHelper)

          expire_time = UserUnlockEntry.pay_roll_notification_final
          # cronSt= "12 19 * * *"
          cronSt = "#{min} #{hr} * * #{(expire_time).to_date.wday}"
          scheduler6.cron cronSt do
            p "++++++++++++++monthly parill notification +++++++++++++++++++"
            # wktime_helper.weekly_auto_approve(expire_time)
            wktime_helper.monthly_approve_l2_notifications(expire_time)
            # wktime_helper.create_nc_for_l1_within_sla(Date.today-day.to_i)
            # wktime_helper = Object.new.extend(WktimeHelper)
            # wktime_helper.create_nc_for_l1_within_unlock_sla(Date.today-day.to_i)
            # wktime_helper.expire_unlock_history
            # wktime_helper.weekly_approve_l1_notifications(Date.today)
            p "++++++++++++++++++++monthly payroll notification ended ++++++++++++"

          end
        end


      end

      end
      #alias_method_chain :show, :plugin # This tells Redmine to allow me to extend show by letting me call it via "show_without_plugin" above.
      # I can outright override it by just calling it "def show", at which case the original controller's method will be overridden instead of extended.
  end



  end


