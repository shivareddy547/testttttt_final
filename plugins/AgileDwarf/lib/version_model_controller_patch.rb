module AgileDwarf
  module Patches

    module VersionPatch
      # HEADING_RE = /(<h(\d)( [^>]+)?>(.+?)<\/h(\d)>)/i unless const_defined?(:HEADING_RE)
      def self.included(base)
        # base.extend(ClassMethods)
        # base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
          validate :start_and_end_dates
          validates_presence_of :goal,:velocity,:ir_start_date,:ir_end_date
          validates_numericality_of :velocity

          def start_and_end_dates
            errors.add_to_base("Sprint cannot end before it starts") if self.ir_start_date && self.ir_end_date && self.ir_start_date >= self.ir_end_date
          end




        end
      end
    end

    module VersionControllerPatch
      # HEADING_RE = /(<h(\d)( [^>]+)?>(.+?)<\/h(\d)>)/i unless const_defined?(:HEADING_RE)
      def self.included(base)
        # base.extend(ClassMethods)
        # base.send(:include, InstanceMethods)

        base.class_eval do
          # display a page (in editing mode if it doesn't exist)
          def create
            # @version = @project.versions.build
            @version = Version.new(params[:version])
            @version.project_id=@project.id

            if params[:version]
              attributes = params[:version].dup
              attributes.delete('sharing') unless attributes.nil? || @version.allowed_sharings.include?(attributes['sharing'])
              @version.safe_attributes = attributes
            end


            if request.post?
              if @version.save
                respond_to do |format|
                  format.html do
                    flash[:notice] = l(:notice_successful_create)
                    redirect_back_or_default settings_project_path(@project, :tab => 'versions')
                  end
                  format.js
                  format.api do
                    render :action => 'show', :status => :created, :location => version_url(@version)
                  end
                end
              else
                respond_to do |format|
                  format.html { render :action => 'new' }
                  format.js   { render :action => 'new' }
                  format.api  { render_validation_errors(@version) }
                end
              end
            end
          end
        end
      end
    end


  end
end



