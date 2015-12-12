module WikiChanges
  module Patches
    module ApplicationHelperPatch
      HEADING_RE = /(<h(\d)( [^>]+)?>(.+?)<\/h(\d)>)/i unless const_defined?(:HEADING_RE)
      def self.included(base)
        # base.extend(ClassMethods)
        # base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
          def textilizable1(*args)
            options = args.last.is_a?(Hash) ? args.pop : {}
             case args.size
              when 1
                obj = options[:object]
                text = args.shift
              when 2
                p obj = args.shift
                p attr = args.shift
                # check_current_user_allowed?(link_project,page)
                check_role = user_allowed_to_edit?(obj.page.wiki.project,obj.page.id)
                if user_allowed_to_edit?(obj.page.wiki.project,obj.page.id)
                  text = obj.send(attr).to_s
                else
                  text = ""
                end

              # text = obj.send(attr).to_s

              else
                raise ArgumentError, 'invalid arguments to textilizable'
            end
            return '' if text.blank?
            project = options[:project] || @project || (obj && obj.respond_to?(:project) ? obj.project : nil)
            @only_path = only_path = options.delete(:only_path) == false ? false : true
            text = text.dup
            macros = catch_macros(text)
            text = Redmine::WikiFormatting.to_html(Setting.text_formatting, text, :object => obj, :attribute => attr)

            @parsed_headings = []
            @heading_anchors = {}
            @current_section = 0 if options[:edit_section_links]

            parse_sections(text, project, obj, attr, only_path, options)
            text = parse_non_pre_blocks(text, obj, macros) do |text|
              p text
              [:parse_inline_attachments, :parse_wiki_links, :parse_redmine_links].each do |method_name|
                send method_name, text, project, obj, attr, only_path, options
              end
            end
            parse_headings(text, project, obj, attr, only_path, options)
            if @parsed_headings.any?
              replace_toc(text, @parsed_headings)
            end

            text.html_safe
          end


#           def check_current_user_allowed1?(project,wiki_page)
#
#
#
#             p "++++++++++++++36363636363663636363==============="
#             p project
#             p wiki_page
#             current_user_membership = Member.where(:user_id=>User.current.id,:project_id=>project.id).first
#             permissions=[]
#
#             permissions=[]
#             p "++++++++= current_user_membership.roles current_user_membership.roles++++++"
#             if current_user_membership.present?
#               p  membership_roles = current_user_membership.roles.map(&:id)
#               page_roles = Role.where(:id=>wiki_page.roles)
#               p current_user_membership
#             end
#             p "++++++++++++++++"
# # current_user_membership.roles.each do |each_role|
# #   permissions << each_role.permissions
# #
# # end
# #
# # p "++++++++++=permissionspermissions+++++++="
# # p member_permissions = permissions.flatten
# # permissions_page=[]
# #
# # p "+++=====wiki_page+++++++="
# # p wiki_page
# # # p wiki_page.roles
# #     if wiki_page.present? &&  wiki_page.roles.present?
# #       roles= Role.where(:id=>wiki_page.roles)
# #       p "++++++++++++++++++++++++++====rolesrolesrolesrolesrolesrolesroles+++++=="
# #       p roles
# #       p "++++++++++++++++++="
# #       roles.each do |each_role|
# #         permissions_page << each_role.permissions
# #       end
# #       permissions_pages = permissions_page.flatten
# #
# #       # user_permission = member_permissions-permissions_pages
# #
# #
# #       p "+++++++++++86868868686868686868+++++++++++++"
# #       p permissions_pages && member_permissions == permissions_pages
# #
# #       user_permission = permissions_pages.zip(member_permissions).map { |a, b| a == b }
# #       p 0000000000000000000000000000
# #       # p member_permissions
# #       # p permissions_pages
# #       p "+++++++=user_permission++++++="
# #
# #       p wiki_page
# #       p permissions_pages
# #       p member_permissions
# #       p user_permission
# #       p user_permission.uniq if user_permission
# #       user_permission.uniq.count if user_permission
# #       p "+++++++++++++end ++++++="
# #
# #
# #     end
# #     p "++++++++++++++++++membership_rolesmembership_rolesmembership_rolesmembership_roles_++++++++=="
# #     p membership_roles
#             p role_ids=page_roles.map(&:id)
#             p "++++++++++++++==="
#             role_true=[]
#             role_ids.each do |each_rr|
#               if membership_roles.include?(each_rr)
#                 role_true<< true
#               end
#
#             end
#
#             if role_true.present? || User.current.admin ==true
#               return true
#             end
#
#
#
#           end



          def user_allowed_to_edit?(project,page_id)
            permissions =[]
            current_user_membership = Member.where(:user_id=>User.current.id,:project_id=>project.id).first
            @page = WikiPage.find_by_id(page_id)
           if @page.present? && @page.wiki_roles.present? && current_user_membership.present? && current_user_membership.roles.present?
            roles_for_permissions = @page.wiki_roles.where(:role=>current_user_membership.roles.map(&:id))
            roles_for_permissions.each do |wiki_role|
              permissions << wiki_role.permissions
            end
            # p "+++++++++98785698796857577759785+++++++++++++++=="
            # p permissions
            # p permissions.flatten.compact.include?("edit_wiki_pages")
            # user_roles = current_user_membership.roles
             return (permissions.present? && (permissions.flatten.compact.include?("edit_wiki_pages") == true)) || User.current.admin? ? true : ""
            end
            end

          def user_allowed_to_view?(project,page_id)
            permissions =[]

            current_user_membership = Member.where(:user_id=>User.current.id,:project_id=>project.id).first
            @page = WikiPage.find_by_id(page_id)
            if @page.present? && @page.wiki_roles.present? && current_user_membership.present? && current_user_membership.roles.present?
              roles_for_permissions = @page.wiki_roles.where(:role=>current_user_membership.roles.map(&:id))
              roles_for_permissions.each do |wiki_role|
                permissions << wiki_role.permissions
              end
              # p "+++++++++98785698796857577759785+++++++++++++++=="
              # p permissions
              # p permissions.flatten.compact.include?("edit_wiki_pages")
              # user_roles = current_user_membership.roles
              return (permissions.present? && (permissions.flatten.compact.include?("view_wiki_pages") == true)) || User.current.admin? ? true : ""
            end
          end


          def user_allowed_to_manage_wiki_roles?(project,page_id)
            permissions =[]
            current_user_membership = Member.where(:user_id=>User.current.id,:project_id=>project.id).first
            @page = WikiPage.find_by_id(page_id)
            if @page.present? && @page.wiki_roles.present? && current_user_membership.present? && current_user_membership.roles.present?
              roles_for_permissions = @page.wiki_roles.where(:role=>current_user_membership.roles.map(&:id))
              roles_for_permissions.each do |wiki_role|
                permissions << wiki_role.permissions
              end
              # p "+++++++++98785698796857577759785+++++++++++++++=="
              # p permissions
              # p permissions.flatten.compact.include?("edit_wiki_pages")
              # user_roles = current_user_membership.roles
              p 5555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
              p permissions.flatten.compact.include?("manage_wiki_pages_roles")
              return ((permissions.present? && (permissions.flatten.compact.include?("manage_wiki_pages_roles") == true)) || (User.current.admin?)) ? true : ""
            end
          end

          def parse_sections(text, project, obj, attr, only_path, options)
            return unless options[:edit_section_links] && user_allowed_to_edit?(project,obj.page_id)
            text.gsub!(HEADING_RE) do
              heading = $1
              @current_section += 1
              if @current_section > 1
                content_tag('div',
                            link_to(image_tag('edit.png'), options[:edit_section_links].merge(:section => @current_section)),
                            :class => 'contextual',
                            :title => l(:button_edit_section),
                            :id => "section-#{@current_section}") + heading.html_safe
              else
                heading
              end
            end
          end


        end
      end
   end
    module WikiPagePatch
      # HEADING_RE = /(<h(\d)( [^>]+)?>(.+?)<\/h(\d)>)/i unless const_defined?(:HEADING_RE)
      def self.included(base)
        # base.extend(ClassMethods)
        # base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
          # serialize :role_permissions, Array
          # serialize :roles, Array
          # has_many :wiki_roless
          # serialize :permissions, Array
          has_many :wiki_roles, :class_name => 'WikiRoles', :foreign_key => 'wiki_page_id', :dependent => :destroy
          # after_create :create_wiki_roles, if: :author_wants_emails?,
          #              unless: Proc.new { |comment| comment.article.ignore_comments? }
          # accepts_nested_attributes_for :wiki_roles, allow_destroy: true
          # safe_attributes 'roles', 'roles',
          #                 :if => lambda {|page, user| page.new_record? || user.allowed_to?(:rename_wiki_pages, page.project)}
          # safe_attributes 'permissions', 'permissions',
          #                 :if => lambda {|page, user| page.new_record? || user.allowed_to?(:rename_wiki_pages, page.project)}
          after_save :create_wiki_roles
          def create_wiki_roles
            project = self.project
            if self.wiki.pages.count ==1
            member_roles = []
             project.members.each do |each_member|
              member_roles << each_member.roles
             end
             member_roles.flatten.compact.uniq.each do |each_role|
                permissions=[]
                if each_role.permissions.present?
                if each_role.permissions.include?("view_wiki_pages".to_sym)
                  permissions << "view_wiki_pages"

                 end
                if each_role.permissions.include?("edit_wiki_pages".to_sym)
                    permissions << "edit_wiki_pages"
                  end
                if each_role.permissions.include?("manage_wiki_pages_roles".to_sym)
                    permissions << "manage_wiki_pages_roles"
                end
                end

                if permissions.present?
                wiki_role = WikiRoles.find_or_initialize_by_role_and_wiki_page_id(each_role.id,self.id)
                wiki_role.permissions=permissions
                wiki_role.wiki_page_id=self.id
                wiki_role.save
                # wiki_role.save
                  # wiki_role.update_attributes(:permisssion=>permissions)
                end

            end

            end
          end


          def self.update_wiki_roles_for_exist_pages
            # project = self.project

             Project.active.each do |each_project|
               project_roles = []
               each_project.members.each do |project_member|
                 project_roles << project_member.roles.map(&:id) if project_member.roles.present?
               end

               if project_roles.present?
                 project_roles = project_roles.flatten.compact

                 project_roles.each do |each_role|

                 if each_project.wiki.present? && each_project.wiki.pages.present?
                 each_project.wiki.pages.each do |wiki_page|
                 each_role = Role.find(each_role)
                 permissions=[]
                 if each_role.permissions.present?
                   if each_role.permissions.include?("view_wiki_pages".to_sym)
                     permissions << "view_wiki_pages"

                   end
                   if each_role.permissions.include?("edit_wiki_pages".to_sym)
                     permissions << "edit_wiki_pages"
                   end
                   if each_role.permissions.include?("manage_wiki_pages_roles".to_sym)
                     permissions << "manage_wiki_pages_roles"
                   end
                 end

                 if permissions.present?
                   wiki_role = WikiRoles.find_or_initialize_by_role_and_wiki_page_id(each_role.id,wiki_page.id)
                   wiki_role.permissions=permissions
                   wiki_role.wiki_page_id=wiki_page.id
                   wiki_role.save
                   # wiki_role.save
                   # wiki_role.update_attributes(:permisssion=>permissions)
                 end

                 end

                 end
               end
               end

               # each_project.wiki.pages.each do |wiki_page|
               #
               #
               #
               # end

             end
          end

        end
      end
    end

    module WikiControllerPatch
      # HEADING_RE = /(<h(\d)( [^>]+)?>(.+?)<\/h(\d)>)/i unless const_defined?(:HEADING_RE)
      def self.included(base)
        # base.extend(ClassMethods)
        # base.send(:include, InstanceMethods)

        base.class_eval do
          # display a page (in editing mode if it doesn't exist)
          def show

            update_wiki_roles_for_project(@project,@page.id)
            if !User.current.admin? && !@page.new_record? && !user_allowed_to_edit?(@project,@page.id).present? && !user_allowed_to_view?(@project,@page.id).present?
              render_permission_denied
              return
            end

            if params[:version] && user_allowed_to_edit?(@project,@page.id).nil?  && !User.current.allowed_to?(:view_wiki_edits, @project)
              deny_access
              return
            end
            @content = @page.content_for_version(params[:version])
            if @content.nil?
              if User.current.allowed_to?(:edit_wiki_pages, @project) && editable? && !api_request?
                edit
                render :action => 'edit'
              else
                render_permission_denied
              end
              return
            end
            if User.current.allowed_to?(:export_wiki_pages, @project)
              if params[:format] == 'pdf'
                send_data(wiki_page_to_pdf(@page, @project), :type => 'application/pdf', :filename => "#{@page.title}.pdf")
                return
              elsif params[:format] == 'html'
                export = render_to_string :action => 'export', :layout => false
                send_data(export, :type => 'text/html', :filename => "#{@page.title}.html")
                return
              elsif params[:format] == 'txt'
                send_data(@content.text, :type => 'text/plain', :filename => "#{@page.title}.txt")
                return
              end
            end
            @editable = editable? && user_allowed_to_edit?(@project,@page.id).present? || User.current.admin?
            @sections_editable = @editable && User.current.allowed_to?(:edit_wiki_pages, @page.project) &&
                @content.current_version? &&
                Redmine::WikiFormatting.supports_section_edit?

            respond_to do |format|
              format.html
              format.api
            end
          end

          # edit an existing page or a new one
          def edit

            if !User.current.admin? && !@page.new_record? && !user_allowed_to_edit?(@project,@page.id).present?
              render_permission_denied
              return
            end
            return render_403 unless editable?
            if @page.new_record?
              if params[:parent].present?
                @page.parent = @page.wiki.find_page(params[:parent].to_s)
              end
            end

            @content = @page.content_for_version(params[:version])
            @content ||= WikiContent.new(:page => @page)
            @content.text = initial_page_content(@page) if @content.text.blank?
            # don't keep previous comment
            @content.comments = nil

            # To prevent StaleObjectError exception when reverting to a previous version
            @content.version = @page.content.version if @page.content

            @text = @content.text
            if params[:section].present? && Redmine::WikiFormatting.supports_section_edit?
              @section = params[:section].to_i
              @text, @section_hash = Redmine::WikiFormatting.formatter.new(@text).get_section(@section)
              render_permission_denied if @text.blank?
            end
          end

          # Creates a new page or updates an existing one
          def update
            return render_403 unless editable?
            was_new_page = @page.new_record?
            @page.safe_attributes = params[:wiki_page]
            @content = @page.content || WikiContent.new(:page => @page)
            content_params = params[:content]
            if content_params.nil? && params[:wiki_page].is_a?(Hash)
              content_params = params[:wiki_page].slice(:text, :comments, :version)
            end
            content_params ||= {}

            @content.comments = content_params[:comments]
            @text = content_params[:text]
            if params[:section].present? && Redmine::WikiFormatting.supports_section_edit?
              @section = params[:section].to_i
              @section_hash = params[:section_hash]
              @content.text = Redmine::WikiFormatting.formatter.new(@content.text).update_section(@section, @text, @section_hash)
            else
              @content.version = content_params[:version] if content_params[:version]
              @content.text = @text
            end
            @content.author = User.current

            if @page.save_with_content(@content)

              save_permissions_with_role(params,@page)

              attachments = Attachment.attach_files(@page, params[:attachments])
              render_attachment_warning_if_needed(@page)
              call_hook(:controller_wiki_edit_after_save, { :params => params, :page => @page})

              respond_to do |format|
                format.html {
                  anchor = @section ? "section-#{@section}" : nil
                  redirect_to project_wiki_page_path(@project, @page.title, :anchor => anchor)
                }
                format.api {
                  if was_new_page
                    render :action => 'show', :status => :created, :location => project_wiki_page_path(@project, @page.title)
                  else
                    render_api_ok
                  end
                }
              end
            else
              respond_to do |format|
                format.html { render :action => 'edit' }
                format.api { render_validation_errors(@content) }
              end
            end

          rescue ActiveRecord::StaleObjectError, Redmine::WikiFormatting::StaleSectionError
            # Optimistic locking exception
            respond_to do |format|
              format.html {
                flash.now[:error] = l(:notice_locking_conflict)
                render :action => 'edit'
              }
              format.api { render_api_head :conflict }
            end
          rescue ActiveRecord::RecordNotSaved
            respond_to do |format|
              format.html { render :action => 'edit' }
              format.api { render_validation_errors(@content) }
            end
          end

          def update_wiki_roles_for_project(params,page)

            # if params[:remove_roles].present?
            #   remove_wiki_role = WikiRoles.where(wiki_page_id: @page.id,role:params[:remove_roles])
            #   remove_wiki_role.each do |wiki_role|
            #     wiki_role.delete
            #   end
            # end
            #
            # if params[:role].present?
            #   params[:role].each_with_index do |role, index|
            #     if role.present?
            #       wiki_role = WikiRoles.find_or_initialize_by_role_and_wiki_page_id(role,@page.id)
            #       wiki_role.permisssion=params["permissions#{index}"]
            #       wiki_role.wiki_page_id=@page.id
            #       wiki_role.save
            #     end
            #   end
            # end
            #
            # # tags.each_with_index do |tag, index|
            # #   tag = Tag.create :name => tag
            # #   Skill.create :tag_id => tag.id, :weight => weights[index]
            # # end
          end

          def save_permissions_with_role(params,page)

            if params[:remove_roles].present?
              remove_wiki_role = WikiRoles.where(wiki_page_id: @page.id,role:params[:remove_roles])
              remove_wiki_role.each do |wiki_role|
                wiki_role.delete
              end
            end

            if params[:role].present?
              params[:role].each_with_index do |role, index|
                if role.present?
                  wiki_role = WikiRoles.find_or_initialize_by_role_and_wiki_page_id(role,@page.id)
                  wiki_role.permissions=params["permissions#{index}"]
                  wiki_role.wiki_page_id=@page.id
                  wiki_role.save
                end
              end
            end
            if params[:detail].present?
              @roles = WikiRoles.where(wiki_page_id: @page.id,role:params[:detail][:update_child_pages])
              @child_pages=WikiPage.where(:parent_id=>@page.id)
              if @child_pages.present?
                @child_pages.each do |each_child|
                 @roles.each do |each_role|
                   find_parent_permissions = WikiRoles.where(:role=>each_role.role,:wiki_page_id=>@page.id)
                    wiki_role = WikiRoles.find_or_initialize_by_role_and_wiki_page_id(each_role.role,each_child.id)
                    wiki_role.permissions=find_parent_permissions.last.permissions
                    wiki_role.wiki_page_id=each_child.id
                    wiki_role.save
                end
              end
              end
            end




            # tags.each_with_index do |tag, index|
            #   tag = Tag.create :name => tag
            #   Skill.create :tag_id => tag.id, :weight => weights[index]
            # end
          end

          def render_permission_denied
            @message = "Permissions denied..!"
            respond_to do |format|
              format.html {
                render :template => 'wiki_changes/permission_denied', :layout => 'layouts/base'
                #render template: 'wiki_changes/permission_denied', layout: 'layouts/application'
                }

               format.all { render nothing: true, status: 404 }
            end
          end

        end
      end
    end


  end
end



