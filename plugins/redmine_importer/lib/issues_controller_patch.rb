module IssuesControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
      # Issues Bulk update with out Activities updation


      def update
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

      # def update
      #
      #   return unless update_issue_from_params
      #   @issue.update_attributes(:bulk_update=>false,:imported=>false)
      #   @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
      #   saved = false
      #   begin
      #     saved = save_issue_with_child_records
      #   rescue ActiveRecord::StaleObjectError
      #     @conflict = true
      #     if params[:last_journal_id]
      #       @conflict_journals = @issue.journals_after(params[:last_journal_id]).all
      #       @conflict_journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @issue.project)
      #     end
      #   end
      #
      #   if saved
      #     @issue.self_parent_update
      #     render_attachment_warning_if_needed(@issue)
      #     flash[:notice] = l(:notice_successful_update) unless @issue.current_journal.new_record?
      #
      #     respond_to do |format|
      #       format.html { redirect_back_or_default issue_path(@issue) }
      #       format.api  { render_api_ok }
      #     end
      #   else
      #     respond_to do |format|
      #       format.html { render :action => 'edit' }
      #       format.api  { render_validation_errors(@issue) }
      #     end
      #   end
      # end


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
          journal = issue.init_journal(User.current, params[:notes])
          issue.safe_attributes = attributes
          call_hook(:controller_issues_bulk_edit_before_save, { :params => params, :issue => issue })
          if issue.save
            saved_issues << issue
          else
            unsaved_issues << orig_issue
          end
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
#
#   unsaved_issues = []
#   saved_issues = []
#
#   if @copy && params[:copy_subtasks].present?
#     # Descendant issues will be copied with the parent task
#     # Don't copy them twice
#     @issues.reject! {|issue| @issues.detect {|other| issue.is_descendant_of?(other)}}
#   end
#   sql_values=""
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
#
#     if issue.valid?
#       # saved_issues << issue
#       #description
#       #issue.description = issue.description.scan(/'(.+?)'|"(.+?)"|"(=)"|([^ ]+)/).flatten.compact.join(',') if issue.description.present?
#       #issue.subject = issue.subject.scan(/'(.+?)'|"(.+?)"|([^ ]+)/).flatten.compact.join(',') if issue.description.present?
#       issue.description = issue.description.gsub(/[^0-9A-z .,->:;<()]/,'') if issue.description.present?
#       issue.subject = issue.subject.gsub(/[^0-9A-z .,->:;<()]/,'') if issue.subject.present?
#       issue.updated_on = Time.now
#       issue.created_on = Time.now
#       saved_issues << issue
#       @saved_issues_attributes = issue.attributes.keys.*','
#       saved_issues_values = issue.attributes.values
#       sql_values = sql_values + "(#{ saved_issues_values.map{ |i| '"%s"' % i }.join(', ') }),"
#       connection = ActiveRecord::Base.connection
#       # if issue.id.present?
#       #   sql_query_for_parent="UPDATE issues set root_id=#{issue.id},parent_id=#{issue.parent_id.present? && issue.parent_id !=0 ? issue.parent_id : "NULL"},lft=#{Issue.maximum(:lft) + 1},rgt=#{Issue.maximum(:rgt) + 1}  where id = #{issue.id}"
#       #   connection.execute(sql_query_for_parent.to_s)
#       # else
#       #   sql_for_inserted_id="SELECT LAST_INSERT_ID() from issues LIMIT 1"
#       #   find_inserted_record =connection.execute(sql_for_inserted_id)
#       #   if find_inserted_record.present? && find_inserted_record.first[0] != 0
#       #     issue = Issue.find(find_inserted_record.first[0])
#       #     sql_query_for_parent="UPDATE issues set root_id=#{issue.id},parent_id=#{issue.parent_id.present? && issue.parent_id !=0 ? issue.parent_id : "NULL"},lft=#{Issue.maximum(:lft) + 1},rgt=#{Issue.maximum(:rgt) + 1}  where id = #{issue.id}"
#       #     connection.execute(sql_query_for_parent.to_s)
#       #   end
#       # end
#
#
#
#       sql_values=""
#       if !issue.id.present?
#         issue.created_on = Time.now
#       end
#
#       issue.updated_on = Time.now
#       @saved_issues_attributes = issue.attributes.keys.*','
#       saved_issues_values = issue.attributes.values
#       sql_values = sql_values + "(#{ saved_issues_values.map{ |i| '"%s"' % i }.join(', ') }),"
#       sql_values=sql_values.chomp(',')
#       sql_query= "VALUES#{sql_values}"
#       final_sql = "REPLACE INTO issues (#{@saved_issues_attributes}) #{sql_query}"
#       connection = ActiveRecord::Base.connection
#       connection.execute(final_sql.to_s)
#       if issue.id.present?
#
#         if (issue.parent_id.present? && issue.parent_id != 0) ||  params[:issue][:parent_issue_id].present?
#            # issue.save_parent_value(params[:issue][:parent_issue_id])
#
#           parent = Issue.find(params[:issue][:parent_issue_id].present? ? params[:issue][:parent_issue_id] : issue.parent_id)
#           if parent.present?
#
#             Issue.where(id: issue.id).update_all(:parent_id=>parent.id,:root_id=>parent.id,:lft=>parent.rgt+0,:rgt=>parent.rgt+1)
#             updated_issue = Issue.find(issue.id)
#             Issue.where(id: parent.id).update_all(:root_id=>parent.id,:rgt=>updated_issue.rgt+1)
#
#           end
#
#          else
#           Issue.where(id: issue.id).update_all(:root_id=>issue.id,:parent_id=>issue.parent_id.present? && issue.parent_id != 0 ? issue.parent_id : nil)
#         end
#         # sql_query_for_parent="UPDATE issues set root_id=#{issue.parent_id.present? && issue.parent_id !=0 ? issue.parent_id : issue.id},parent_id=#{issue.parent_id.present? && issue.parent_id !=0 ? issue.parent_id : "NULL"},lft=#{Issue.maximum(:lft) + 1},rgt=#{Issue.maximum(:rgt) + 1}  where id = #{issue.id}"
#         # connection.execute(sql_query_for_parent.to_s)
#       else
#         sql_for_inserted_id="SELECT LAST_INSERT_ID() from issues LIMIT 1"
#         find_inserted_record =connection.execute(sql_for_inserted_id)
#         if find_inserted_record.present? && find_inserted_record.first[0] != 0
#
#           issue = Issue.find(find_inserted_record.first[0])
#           # parent_issue = Issue.find(params[:issue][:parent_issue_id]) if params[:issue][:parent_issue_id].present?
#           if (issue.parent_id.present? && issue.parent_id != 0) ||  params[:issue][:parent_issue_id].present?
#             # issue.save_parent_value(params[:issue][:parent_issue_id])
#
#             # parent = Issue.find(params[:issue][:parent_issue_id].present? ? params[:issue][:parent_issue_id] : issue.parent_id)
#
#             parent = Issue.find(params[:issue][:parent_issue_id].present? ? params[:issue][:parent_issue_id] : issue.parent_id)
#             if parent.present?
#
#               Issue.where(id: issue.id).update_all(:parent_id=>parent.id,:root_id=>parent.id,:lft=>parent.rgt+0,:rgt=>parent.rgt+1)
#               updated_issue = Issue.find(issue.id)
#               Issue.where(id: parent.id).update_all(:root_id=>parent.id,:rgt=>updated_issue.rgt+1)
#
#             end
#
#
#           else
#             Issue.where(id: issue.id).update_all(:root_id=>issue.id,:parent_id=> issue.parent_id.present? && issue.parent_id != 0 ? issue.parent_id : nil )
#           end
#           # sql_query_for_parent="UPDATE issues set root_id=#{issue.id},parent_id=#{issue.parent_id.present? && issue.parent_id !=0 ? issue.parent_id : "NULL"},lft=#{Issue.maximum(:lft) + 1},rgt=#{Issue.maximum(:rgt) + 1}  where id = #{issue.id}"
#           # connection.execute(sql_query_for_parent.to_s)
#         end
#       end
#
#
#
#
#     else
#       unsaved_issues << orig_issue
#     end
#
#   end
# # Sql for copy and updation.
# #   if saved_issues.present?
# #     sql_values=sql_values.chomp(',')
# #     sql_query= "VALUES#{sql_values}"
# #     final_sql = "REPLACE INTO issues (#{@saved_issues_attributes}) #{sql_query}"
# #     connection = ActiveRecord::Base.connection
# #     Rails.logger.info final_sql
# #     connection.execute(final_sql.to_s)
# #   end
#   Issue.set_callback("create",:after,:send_notification)
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
#     Rails.logger.info "++++++++++not valid +++++++++++"
#     @saved_issues = @issues
#     @unsaved_issues = unsaved_issues
#     @issues = Issue.visible.where(:id => @unsaved_issues.map(&:id)).all
#     bulk_edit
#     render :action => 'bulk_edit'
#   end
# end

    end
  end

  def save_parent_value(issue,parent_id)
    p "+++++++++++pareeeeeeeeeeeeeeeee++++++++"
    p parent_id
    p parent = Issue.find(parent_id)
    issue = Issue.find(issue)
    if parent.present?
      p "++++++++++++++present++++++++++++++++++++++++="
      Issue.where(id: issue.id).update_all(:parent_id=>parent.id,:root_id=>parent.id,:lft=>parent.rgt,:rgt=>parent.rgt+1)
      Issue.where(id: parent.id).update_all(:root_id=>parent.id,:rgt=>issue.rgt+1)
    end
    p "+++++++++++++++++++++++++updated issue +++++++++++++++++++++"
    p parent
    p issue
    p "++++++++++++++++++++++++++++++++end ++++++++++++++++++++++++++++++"

  end
end
