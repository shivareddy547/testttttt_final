module IssuesControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
      # Issues Bulk update with out Activities updation

      # Bulk update copy issues and status update sql queries updated
      def bulk_update
        Rails.logger.info  111111111111111111111111111111111111111111111111111111111111111111111111
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
          sql_values=""
          #           if !issue.id.present? && issue.valid?
          #             # saved_issues << issue
          #             issue.description = issue.description.gsub(/\s|"|'/, ' ')
          #             issue.subject= issue.subject.gsub(/\s|"|'/, ' ')
          #            # issue.description = issue.description.scan(/'(.+?)'|"(.+?)"|([^ ]+)/).flatten.compact.join(' ') if issue.description.present?
          #            # issue.subject = issue.subject.scan(/'(.+?)'|"(.+?)"|([^ ]+)/).flatten.compact.join(' ') if issue.description.present?
          #             issue.updated_on = Time.now
          #             issue.created_on = Time.now
          #             issue.parent_id=""
          #             #issue.root_id = Issue.last.id + 1
          #             saved_issues << issue
          #             @saved_issues_attributes = issue.attributes.keys.*','
          #             saved_issues_values = issue.attributes.values
          #             sql_values = sql_values + "(#{ saved_issues_values.map{ |i| '"%s"' % i }.join(', ') }),"
          #             sql_values=sql_values.chomp(',')
          #                     sql_query= "VALUES#{sql_values}"
          #                     final_sql = "REPLACE INTO issues (#{@saved_issues_attributes}) #{sql_query}"
          #                     Rails.logger.info final_sql
          #                     connection = ActiveRecord::Base.connection
          #                     Rails.logger.info final_sql
          #                     connection.execute(final_sql.to_s)
          #
          #
          #                     #sql_for_inserted_id="SELECT LAST_INSERT_ID() from issues LIMIT 1"
          #             sql_for_inserted_id="SELECT id FROM issues ORDER BY updated_on DESC LIMIT 1;"
          #
          #                     find_inserted_record =connection.execute(sql_for_inserted_id)
          #
          #             puts 3333333333333333
          #             puts find_inserted_record
          #             puts 44444444444444444444
          #
          #             if find_inserted_record.present? && find_inserted_record.first[0] != 0
          # puts 11111111111111111111111111
          # puts find_inserted_record.first[0]
          # puts 22222222222222222222
          #                 issue = Issue.find(find_inserted_record.first[0])
          #                sql_query_for_parent="UPDATE issues set root_id=#{issue.id},parent_id=NULL  where id = #{issue.id}"
          #             connection.execute(sql_query_for_parent.to_s)
          #            end
          #             #issue.parent_id=nil
          #             #issue.root_id=issue.id
          #             #issue.save
          #             #parent_id = issue.parent_id.present? && issue.parent_id != 0 ? issue.parent_id : ""
          #
          #            # issue.update_attributes(:parent_id=>" ")
          #            # issue.update_attributes(:root_id=>issue.id)
          #           else
          #             unsaved_issues << orig_issue
          #           end
          if issue.valid?
            issue.description = issue.description.gsub(/\s|"|'/, ' ')
            issue.subject= issue.subject.gsub(/\s|"|'/, ' ')
            # issue.description = issue.description.scan(/'(.+?)'|"(.+?)"|([^ ]+)/).flatten.compact.join(' ') if issue.description.present?
            # issue.subject = issue.subject.scan(/'(.+?)'|"(.+?)"|([^ ]+)/).flatten.compact.join(' ') if issue.description.present?
            if !issue.id.present?
              issue.created_on = Time.now
              # issue.lft = Issue.maximum(:lft) + 1
              #issue.rgt = Issue.maximum(:rgt) + 1
            end
            issue.updated_on = Time.now
            #issue.parent_id=issue.parent_id.present? issue.parent_id : ""
            #issue.root_id = Issue.last.id + 1
            saved_issues << issue
            @saved_issues_attributes = issue.attributes.keys.*','
            saved_issues_values = issue.attributes.values
            sql_values = sql_values + "(#{ saved_issues_values.map{ |i| '"%s"' % i }.join(', ') }),"
            sql_values=sql_values.chomp(',')
            sql_query= "VALUES#{sql_values}"
            final_sql = "REPLACE INTO issues (#{@saved_issues_attributes}) #{sql_query}"
            Rails.logger.info final_sql
            connection = ActiveRecord::Base.connection
            Rails.logger.info final_sql
            connection.execute(final_sql.to_s)
            if issue.id.present?
              issue.update_attributes(:custom_field_values => params[:issue][:custom_field_values]) if params[:issue] && params[:issue][:custom_field_values]
              sql_query_for_parent="UPDATE issues set root_id=#{issue.id},parent_id=#{issue.parent_id.present? && issue.parent_id !=0 ? issue.parent_id : "NULL"},lft=#{Issue.maximum(:lft) + 1},rgt=#{Issue.maximum(:rgt) + 1}  where id = #{issue.id}"
              connection.execute(sql_query_for_parent.to_s)
            else
              #issue.updated_on = Time.now
              #sql_for_inserted_id="SELECT id FROM issues ORDER BY updated_on DESC LIMIT 1;"
              sql_for_inserted_id="SELECT LAST_INSERT_ID() from issues LIMIT 1"
              find_inserted_record =connection.execute(sql_for_inserted_id)
              if find_inserted_record.present? && find_inserted_record.first[0] != 0
                issue = Issue.find(find_inserted_record.first[0])
                issue.update_attributes(:custom_field_values => params[:issue][:custom_field_values]) if params[:issue] && params[:issue][:custom_field_values]
                sql_query_for_parent="UPDATE issues set root_id=#{issue.id},parent_id=#{issue.parent_id.present? && issue.parent_id !=0 ? issue.parent_id : "NULL"},lft=#{Issue.maximum(:lft) + 1},rgt=#{Issue.maximum(:rgt) + 1}  where id = #{issue.id}"
                connection.execute(sql_query_for_parent.to_s)
              end
            end
            #sql_for_inserted_id="SELECT LAST_INSERT_ID() from issues LIMIT 1"
            #  sql_for_inserted_id="SELECT id FROM issues ORDER BY updated_on DESC LIMIT 1;"
            #
            # find_inserted_record =connection.execute(sql_for_inserted_id)
            #
            # puts 3333333333333333
            # puts find_inserted_record
            # puts 44444444444444444444
            #
            # if find_inserted_record.present? && find_inserted_record.first[0] != 0
            #   puts 11111111111111111111111111
            #   puts find_inserted_record.first[0]
            #   puts 22222222222222222222
            #   issue = Issue.find(find_inserted_record.first[0])
            #   sql_query_for_parent="UPDATE issues set root_id=#{issue.id},parent_id=NULL  where id = #{issue.id}"
            #   connection.execute(sql_query_for_parent.to_s)
            # end
            #issue.parent_id=nil
            #issue.root_id=issue.id
            #issue.save
            #parent_id = issue.parent_id.present? && issue.parent_id != 0 ? issue.parent_id : ""

            # issue.update_attributes(:parent_id=>" ")

          end



        end
# Sql for copy and updation.
#         sql_values=sql_values.chomp(',')
#         sql_query= "VALUES#{sql_values}"
#         final_sql = "SELECT REPLACE INTO issues (#{@saved_issues_attributes}) #{sql_query}"
#         Rails.logger.info final_sql
#         connection = ActiveRecord::Base.connection
#         Rails.logger.info final_sql
#         connection.execute(final_sql.to_s)
#         config = ActiveRecord::Base.configurations["production"].symbolize_keys
#         conn = Mysql2::Client.new(config)
#         conn.query(final_sql.to_s).each do |user|
#           # user should be a hash
#           puts 444444444444444444444
#         end
#         puts 3333333333333333333333
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

    end
  end
end
