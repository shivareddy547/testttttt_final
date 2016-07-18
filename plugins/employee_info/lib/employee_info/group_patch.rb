module EmployeeInfo

    module GroupPatch
      def self.included(base)
        #base.extend(ClassMethods)

        #base.send(:include, InstanceMethods)

        base.class_eval do
        has_one :user_official_info


        def user_added(user)
          members.each do |member|
            next if member.project.nil?
            user_member = Member.find_by_project_id_and_user_id(member.project_id, user.id) || Member.new(:project_id => member.project_id, :user_id => user.id)
            user_member.billable="3"
            member.member_roles.each do |member_role|
              user_member.member_roles << MemberRole.new(:role => member_role.role, :inherited_from => member_role.id)
            end
            user_member.save!
          end
        end

        end
      end



    end
  end




