module IssuesControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
      def create
        subject = params[:issue][:subject]
        p '========= am ticket --------------'
        call_hook(:controller_issues_new_before_save, { :params => params, :issue => @issue })
        @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))

        if @issue.save
          if @issue.tracker.core_fields.include? 'approval_workflow'

            ticket = params[:ticket]
            project = Project.find_by_identifier(params[:project_id])
            project_id = ticket[:project_id].present? ? ticket[:project_id] : project.id
            if ProjectCategory.find(ticket[:category_id]).need_approval
              e = CategoryApprovalConfig.find(subject)
              if e.present?
                text = (e.value1.nil? ? '': e.value1)+" "+(e.value2.nil? ? '': e.value2)+" "+(e.value3.nil? ? '': e.value3)+" "+(e.value4.nil? ? '': e.value4)+" "+(e.value5.nil? ? '': e.value5)
                @issue.update_attributes(subject: text)

                request = TicketingApproval.new(issue_id: @issue.id, project_id: project_id, category_approval_config_id: e.id)
                request.save
              end
              @issue.make_sure_tickets?
            else
              default_assignee =  DefaultAssigneeSetup.find_or_initialize_by_project_id_and_tracker_id(:project_id=> @issue.project_id ,:tracker_id=>@issue.tracker_id)
              NonApprovalTicket.create(issue_id: @issue.id, project_id: project_id, project_category_id: ticket[:category_id])
              @issue.assigned_to_id = default_assignee.default_assignee_to
              status = IssueStatus.find_by_name('open')
              @issue.status_id = status.id
              @issue.save
            end

          end
          call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
          respond_to do |format|
            format.html {
              render_attachment_warning_if_needed(@issue)
              flash[:notice] = l(:notice_issue_successful_create, :id => view_context.link_to("##{@issue.id}", issue_path(@issue), :title => @issue.subject))
              if params[:continue]
                attrs = {:tracker_id => @issue.tracker, :parent_issue_id => @issue.parent_issue_id}.reject {|k,v| v.nil?}
                redirect_to new_project_issue_path(@issue.project, :issue => attrs)
              else
                redirect_to issue_path(@issue)
              end
            }
            format.api  { render :action => 'show', :status => :created, :location => issue_url(@issue) }
          end
          return
        else
          respond_to do |format|
            format.html { render :action => 'new' }
            format.api  { render_validation_errors(@issue) }
          end
        end
      end
      def update

        sla_time_helper = Object.new.extend(SlaTimeHelper)
        change_status = false
        if sla_time_helper.redmine_issue_sla_enabled(@issue)
          sla_time_helper.duration_of_ticket(params[:id], params[:issue][:status_id], params[:old_status_id])
          change_status = true if @issue.status_id.to_s != params[:issue][:status_id]
        end
        return unless update_issue_from_params
        @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
        saved = false
        begin
          saved = save_issue_with_child_records
        rescue ActiveRecord::StaleObjectError
          @conflict = true
          if params[:last_journal_id]
            @conflict_journals = @issue.journals_after(params[:last_journal_id]).all
            @conflict_journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @issue.project)
          end
        end

        if saved
          param_priority = params[:issue][:priority_id]
          active_sla = sla_time_helper.redmine_issue_sla_enabled(@issue)
          if active_sla && sla_time_helper.check_sla_hours(@issue) && change_status && @issue.sla_times.present? && @issue.sla_times.last.old_status.sla_timer == 'start'
            dur = @issue.sla_times.last.pre_status_duration
            # total_dur = (dur*100)/60
            hh,mm = dur.divmod(100)
            mm =  mm.to_i.to_s.size > 1 ? mm.to_i : "0#{mm.to_i}"
            s = TimeEntry.new(:project_id => @issue.project.id, :issue_id => @issue.id, :hours => "#{hh}.#{mm}", :comments => sla_time_helper.retun_time_entry_msg(@issue.sla_times.last) , :activity_id => 8 , :spent_on => Date.today)
            s.user_id =  @issue.sla_times.last.user_id
            s.save
          end
          if param_priority.present? && active_sla
            priority = IssuePriority.find(param_priority)
            sla_rec = IssueSla.where(:tracker_id => @issue.tracker.id, :project_id => @issue.project.id, :priority_id => priority.id)
            @issue.update_attributes(:estimated_hours => sla_rec.last.allowed_delay, :priority_id => param_priority) #if @issue.estimated_hours == 0
          end
          render_attachment_warning_if_needed(@issue)
          flash[:notice] = l(:notice_successful_update) unless @issue.current_journal.new_record?

          respond_to do |format|
            format.html { redirect_back_or_default issue_path(@issue) }
            format.api  { render_api_ok }
          end
        else
          respond_to do |format|
            format.html { render :action => 'edit' }
            format.api  { render_validation_errors(@issue) }
          end
        end
      end


      def update_form
        tracker_id =  params[:issue][:tracker_id]
        project = Project.find_by_identifier(params[:project_id])
        tracker = project.trackers.find(tracker_id.to_i)
        @trackp = []
        @tracks = []
        tracker_status =  IssueSlaStatus.where(:project_id => project.id, :tracker_id => tracker.id)
        tracker_sla =  IssueSla.where(:project_id => project.id, :tracker_id => tracker.id)
        tracker_sla.collect{|rec| @trackp << [rec.priority.id, rec.priority.name]}
        tracker_status.collect{|rec| @tracks << [rec.issue_status.id, rec.issue_status.name]}
        respond_to do |format|
          format.js { render :json => [@trackp, @tracks] }
        end
      end
    end
  end
end


