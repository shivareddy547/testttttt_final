module RedmineDefaultAssignee
 module ApplicationHelperPatch
      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)

      end

      module ClassMethods
      end

      module InstanceMethods

        def principals_options_for_select_default(collection, selected=nil)
          s = ''
          if collection.include?(User.current)
            s << content_tag('option', "<< #{l(:label_me)} >>", :value => User.current.id)
          end
          groups = ''
          collection.sort.each do |element|
            selected_attribute = ' selected="selected"' if option_value_selected?(element, selected) || element.id.to_s == selected
            (element.is_a?(Group) ? groups : s) << %(<option value="#{element.id}"#{selected_attribute}>#{h element.name}</option>)
          end
          unless groups.empty?
            s << %(<optgroup label="#{h(l(:label_group_plural))}">#{groups}</optgroup>)
          end
          s.html_safe
        end

      end
 end
  end


