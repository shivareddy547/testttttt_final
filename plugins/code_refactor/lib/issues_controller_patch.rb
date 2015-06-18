module IssuesControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
      # Issues Bulk update with out Activities updation

      # Bulk update copy issues and status update sql queries updated
      def bulk_update
        @issues.sort!
        @copy = params[:copy].present?
        attributes = parse_params_for_bulk_issue_attributes(params)

        unsaved_issues = []
        saved_issues = []

        if @copy && params[:copy_subtasks].present?
          # Descendant issues will be copied with the parent task
          # Don't copy them twice
          @issues.reject! {|issue| @issues.detect {|other| issue.is_descendant_of?(other)}}
        end
        sql_values=""
        @issues.each do |orig_issue|
          orig_issue.reload
          if @copy
            issue = orig_issue.copy({},
                                    :attachments => params[:copy_attachments].present?,
                                    :subtasks => params[:copy_subtasks].present?
            )
          else
            issue = orig_issue
          end
          #journal = issue.init_journal(User.current, params[:notes])
          Issue.skip_callback("create",:after,:send_notification)
          issue.safe_attributes = attributes
          call_hook(:controller_issues_bulk_edit_before_save, { :params => params, :issue => issue })
          # if issue.save
          #   saved_issues << issue
          # else
          #   unsaved_issues << orig_issue
          # end
          Rails.logger.info "++++++++++++++++++++++++test++"
          if issue.valid?
             # saved_issues << issue
            issue.description = issue.description.scan(/'(.+?)'|"(.+?)"|([^ ]+)/).flatten.compact.join(',') if issue.description.present?
            issue.subject = issue.subject.scan(/'(.+?)'|"(.+?)"|([^ ]+)/).flatten.compact.join(',') if issue.description.present?
            issue.updated_on = Time.now
            issue.created_on = Time.now
            saved_issues << issue
            @saved_issues_attributes = issue.attributes.keys.*','
            saved_issues_values = issue.attributes.values
            sql_values = sql_values + "(#{ saved_issues_values.map{ |i| '"%s"' % i }.join(', ') }),"

          else
            unsaved_issues << orig_issue
          end

        end
# Sql for copy and updation.
      if saved_issues.present?
        sql_values=sql_values.chomp(',')
        sql_query= "VALUES#{sql_values}"
        final_sql = "REPLACE INTO issues (#{@saved_issues_attributes}) #{sql_query}"
        connection = ActiveRecord::Base.connection
        Rails.logger.info final_sql
        connection.execute(final_sql.to_s)
        end
        if unsaved_issues.empty?
          flash[:notice] = l(:notice_successful_update) unless saved_issues.empty?
          if params[:follow]
            if @issues.size == 1 && saved_issues.size == 1
              redirect_to issue_path(saved_issues.first)
            elsif saved_issues.map(&:project).uniq.size == 1
              redirect_to project_issues_path(saved_issues.map(&:project).first)
            end
          else
            redirect_back_or_default _project_issues_path(@project)
          end
        else
          Rails.logger.info "++++++++++not valid +++++++++++"
          @saved_issues = @issues
          @unsaved_issues = unsaved_issues
          @issues = Issue.visible.where(:id => @unsaved_issues.map(&:id)).all
          bulk_edit
          render :action => 'bulk_edit'
        end
      end


      # def bulk_update
      #   @issues.sort!
      #   @copy = params[:copy].present?
      #   attributes = parse_params_for_bulk_issue_attributes(params)
      #   unsaved_issues = []
      #   saved_issues = []
      #   if @copy && params[:copy_subtasks].present?
      #     # Descendant issues will be copied with the parent task
      #     # Don't copy them twice
      #     @issues.reject! {|issue| @issues.detect {|other| issue.is_descendant_of?(other)}}
      #   end
      #   sql_values=""
      #   saved_issues_attributes = Issue.new.attributes.keys.*','
      #   @issues.each do |orig_issue|
      #     orig_issue.reload
      #     if @copy
      #       issue = orig_issue.copy({},
      #                               :attachments => params[:copy_attachments].present?,
      #                               :subtasks => params[:copy_subtasks].present?
      #       )
      #     else
      #       issue = orig_issue
      #     end
      #     #journal = issue.init_journal(User.current, params[:notes])
      #     Issue.skip_callback("create",:after,:send_notification)
      #     issue.safe_attributes = attributes
      #     call_hook(:controller_issues_bulk_edit_before_save, { :params => params, :issue => issue })
      #     # if issue.save
      #     #   saved_issues << issue
      #     # else
      #     #   unsaved_issues << orig_issue
      #     # end
      #     if issue.valid?
      #       issue.description = issue.description.scan(/'(.+?)'|"(.+?)"|([^ ]+)/).flatten.compact.join(',') if issue.description.present?
      #       issue.subject = issue.subject.scan(/'(.+?)'|"(.+?)"|([^ ]+)/).flatten.compact.join(',') if issue.description.present?
      #       issue.updated_on = Time.now
      #       issue.created_on = Time.now
      #       saved_issues << issue
      #       saved_issues_values = issue.attributes.values
      #       sql_values = sql_values + "(#{ saved_issues_values.map{ |i| '"%s"' % i }.join(', ') }),"
      #     else
      #       unsaved_issues << orig_issue
      #     end
      #   end
      #   # sql for copy and update
      #   sql_values=sql_values.chomp(',')
      #   sql_query= "VALUES#{sql_values}"
      #   final_sql = "REPLACE INTO issues (#{saved_issues_attributes}) #{sql_query}"
      #   connection = ActiveRecord::Base.connection
      #   connection.execute(final_sql.to_s)
      #   if unsaved_issues.empty?
      #     flash[:notice] = l(:notice_successful_update) unless saved_issues.empty?
      #     if params[:follow]
      #       if @issues.size == 1 && saved_issues.size == 1
      #         redirect_to issue_path(saved_issues.first)
      #       elsif saved_issues.map(&:project).uniq.size == 1
      #         redirect_to project_issues_path(saved_issues.map(&:project).first)
      #       end
      #     else
      #       redirect_back_or_default _project_issues_path(@project)
      #     end
      #   else
      #     @saved_issues = @issues
      #     @unsaved_issues = unsaved_issues
      #     @issues = Issue.visible.where(:id => @unsaved_issues.map(&:id)).all
      #     bulk_edit
      #     render :action => 'bulk_edit'
      #   end
      # end
Rails.logger.info "+++++++++++++++++++++++++++++=end ++++++++++++++++++++++++++"
    end
    end
end
