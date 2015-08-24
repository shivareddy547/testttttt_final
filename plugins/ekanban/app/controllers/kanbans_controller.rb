
class KanbansController < ApplicationController
  unloadable

  PROJECT_VIEW = 0  #Show selected Kanban in Project view
  GROUP_VIEW = 1    #Show selected Kanban in Group view
  MEMBER_VIEW = 2   #Show selected Kanban in Member view

  menu_item :Kanban

  def index
    @project = Project.find(params[:project_id])#Get member name of this project
    @members= @project.members
    @principals = @project.principals
    @user = User.current
    @versions = @project.versions

    @roles = @user.roles_for_project(@project)

    @member = nil
    @principal = nil

    @issue_statuss = IssueStatus.all
    @kanban_states = KanbanState.all
    @issue_status_kanban_state = IssueStatusKanbanState.all
    @kanban_flows = KanbanWorkflow.all

    params[:kanban_id] = 0 if params[:kanban_id].nil?
    params[:member_id] = 0 if params[:member_id].nil?
    params[:principal_id] = 0 if params[:principal_id].nil?

    @kanbans = []

    if params[:kanban_id].to_i > 0
        @kanbans << Kanban.find(params[:kanban_id])
    else
        @kanbans = Kanban.by_project(@project).where("is_valid = ?",true)
    end

    if params[:member_id].to_i == 0 and params[:principal_id].to_i == 0
      @view = PROJECT_VIEW
    elsif params[:member_id].to_i > 0
      @view = MEMBER_VIEW
      @member = Member.find(params[:member_id])
    else
      @view = GROUP_VIEW
      @principal = Principal.find(params[:principal_id])
    end

    #Get all kanbans's name
    @kanban_names = @kanbans.collect{|k| k.name}
    respond_to do |format|
      format.html
      format.js { render :partial => "index", :locals => {:view=>@view, :kanbans=>@Kanbans}}
      format.json { render :json => {:kanbans => @kanbans, 
                                     :teams => @principal, 
                                     :member => @member, 
                                     :view => @view}}
    end
  end

  def panes(kanban)
    #Get all kanban stage/state/
    panes = [] if kanban.nil? or !kanban.is_a?(Kanban)
  	panes = kanban.kanban_pane
  end

  def panes_num(kanban)
    panes(kanban).size
  end

  def cards(pane_id,project)
    cards=[]
    pane = KanbanPane.find(pane_id)

    if !@member.nil?
       cards = KanbanCard.by_member(@member).joins(:priority).find(:all, :conditions => ["kanban_pane_id = ?",pane.id], :order => "#{Enumeration.table_name}.position ASC")
    elsif !@principal.nil?
        cards = KanbanCard.by_group(@principal).joins(:priority).find(:all, :conditions => ["kanban_pane_id = ?",pane.id], :order => "#{Enumeration.table_name}.position ASC")
    else
      # cards = KanbanCard.find_by_sql("SELECT kanban_cards.* FROM kanban_cards INNER JOIN issues ON issues.id = kanban_cards.issue_id INNER JOIN enumerations ON enumerations.id = issues.priority_id AND enumerations.type IN ('IssuePriority') where kanban_pane_id=#{pane.id} order by enumerations.position ASC ")
       cards = KanbanCard.joins(:priority).find(:all, :conditions => ["kanban_pane_id = ?",pane.id], :order => "#{Enumeration.table_name}.position ASC")
    end
    # if pane.present? && pane.kanban.present? && pane.kanban.subproject_enable == true && project.self_and_descendants.active.present?
    # @subprojects = project.self_and_descendants.active
    # pan_ids_array=[]
    # @subprojects.each do |each_project|
    #  if each_project.kanban.present?
    #    kanbans = each_project.kanban.where(:is_valid=>true)
    #    if kanbans.present? && kanbans.count > 0
    #      kanbans.each do |each_kanban|
    #   panes = each_kanban.kanban_pane.where(:name=>pane.name)
    #   pan_ids = panes.map(&:id)
    #   pan_ids_array << pan_ids
    #   end
    #    else
    #      panes = each_project.kanban.last.kanban_pane.where(:name=>pane.name)
    #      pan_ids = panes.map(&:id)
    #      pan_ids_array << pan_ids
    #    end

    #  end
    # end
    # pan_ids_array.flatten!
    # # pan_ids_array = pan_ids_array.flatten!
    # p pan_ids_array
    # if pan_ids_array.present?
    # pan_ids_array.each  do |pane_id|
    #   cards1=[]
    #   pane = KanbanPane.find(pane_id)
    #   # if !@member.nil?
    #   #   cards = KanbanCard.by_member(@member).joins(:priority).find(:all, :conditions => ["kanban_pane_id = ?",pane.id], :order => "#{Enumeration.table_name}.position ASC")
    #   # elsif !@principal.nil?
    #   #   cards = KanbanCard.by_group(@principal).joins(:priority).find(:all, :conditions => ["kanban_pane_id = ?",pane.id], :order => "#{Enumeration.table_name}.position ASC")
    #   # else
    #   #   cards = KanbanCard.joins(:priority).find(:all, :conditions => ["kanban_pane_id = ?",pane.id], :order => "#{Enumeration.table_name}.position ASC")
    #   # end

    #   cards1 = KanbanCard.joins(:priority).find(:all, :conditions => ["kanban_pane_id = ?",pane.id], :order => "#{Enumeration.table_name}.position ASC")

    #   cards = cards + cards1 if cards1.present?

    # end

    # end

    # else


    # pane = KanbanPane.find(pane_id)
    # if !@member.nil?
    #    cards = KanbanCard.by_member(@member).joins(:priority).find(:all, :conditions => ["kanban_pane_id = ?",pane.id], :order => "#{Enumeration.table_name}.position ASC")
    # elsif !@principal.nil?
    #    cards = KanbanCard.by_group(@principal).joins(:priority).find(:all, :conditions => ["kanban_pane_id = ?",pane.id], :order => "#{Enumeration.table_name}.position ASC")
    # else
    #    cards = KanbanCard.joins(:priority).find(:all, :conditions => ["kanban_pane_id = ?",pane.id], :order => "#{Enumeration.table_name}.position ASC")
    # end

    # end
    # p "++++++++=cardscardscardscardscardscardscardscardscardscardscardscards+++"
    # p cards
    # p "++++++++++++end ++++++++="
    # cards.flatten!
    cards = cards.uniq
  end

  def assignee_name(assignee)
    assignee.is_a?(Principal)? assignee.alias : "unassigned"
  end

  def stages_and_panes(panes)
    return nil if panes.empty?
    stages = []
    panes.each do |p|
      next if p.kanban_state.nil?
      next if p.kanban_state.is_closed == true
      state = p.kanban_state
      stage = state.kanban_stage

      st = stages.detect {|s| s[:stage].id == stage.id}
      if !st
        stages << {:stage => stage, :panes => ([] << p), :states => ([]<<state)}
      else
        st[:panes] << p
        st[:states] << state
      end
    end
    stages
  end

  def states(panes)
    return nil if panes.empty?
    panes.collect {|p| p.kanban_state}.sort {|x,y| x.position <=> y.position}
  end

  def show
  end

  def new
    @kanban = Kanban.new
    @project = Project.find(params[:project_id])
    @kanbans = Kanban.find_all_by_project_id(params[:project_id])
    if @kanbans.nil?
      @trackers = Tracker.all
      @copiable_kanbans = Kanbans.all
    else
      used_trackers = []
      @kanbans.each {|k| used_trackers << k.tracker if k.is_valid}
      @trackers = Tracker.all.reject {|t| used_trackers.include?(t)}
    end

    @copiable_kanbans = Kanban.find(:all, :conditions => ["tracker_id in (?) and is_valid = ?", @trackers.select{|t| t.id}, true])
    @copiable_kanbans.each do |k|
	   if k.project.nil?
	      k.name += " - Deleted Project"
	   else
	      k.name += " - #{k.project.name}"
	   end
	end
  end

  def create
    @kanban = Kanban.new(params[:kanban])
    @kanban.created_by = User.current.id
    @kanban.project_id = params[:project_id]
    if request.post? && @kanban.save
      redirect_to settings_project_path(params[:project_id], :tab => 'Kanban')
    else
      render :action => 'new'
    end
  end

  def kanban_settings_tabs
    tabs = [{:name => 'General', :action => :kanban_general, :partial => 'general', :label => :label_kanban_general},
            {:name => 'Panes', :action => :kanban_pane, :partial => 'panes', :label => :label_kanban_panes},
            {:name => 'Workflow', :action => :kanban_workflow, :partial => 'workflow', :label => :label_kanban_workflow},
            ]
    #tabs.select {|tab| User.current.allowed_to?(tab[:action], @project)}
  end

  def update
    @project = Project.find(params[:project_id])
    @kanban = Kanban.find(params[:id])
    if (params[:position])
      @kanban.kanban_pane.each {|p| p.position = params[:position].index("#{p.id}") + 1; p.save}
    end
    if (params[:kanban])
      @kanban.description = params[:kanban][:description]
      @kanban.tracker_id  = params[:kanban][:tracker_id]
      @kanban.name  = params[:kanban][:name]
      @kanban.update_attributes(:is_valid => params[:kanban][:is_valid],:subproject_enable=>params[:kanban][:subproject_enable]);
      @kanban.save
    end


      if @kanban.is_valid == true

      if @project.issues.present?

        @kanban.kanban_pane.each do |each_pane|
         issues = @project.issues.where(:status_id=>each_pane.kanban_state.issue_status.last.id) if each_pane.kanban_state.issue_status.present?
          if issues.present?
          issues.each do |each_issue|
             kanban_new = KanbanCard.find_or_initialize_by_issue_id_and_kanban_pane_id(each_issue.id,each_pane.id)
               kanban_new.issue_id = each_issue.id
               kanban_new.developer_id= each_issue.assigned_to_id
               kanban_new.verifier_id=each_issue.assigned_to_id
               kanban_new.kanban_pane_id=each_pane.id
               kanban_new.save
          end
          end
      end
      end

      if params[:kanban].present? && params[:kanban][:subproject_enable].present? && params[:kanban][:subproject_enable] == "1"
        @kanban.kanban_pane.each do |each_pane|
           @subprojects = @project.descendants.active
           @subprojects_ids = @subprojects.map(&:id).join(',') if @subprojects.present?

          issues=[]
          if each_pane.kanban_state.present? && each_pane.kanban_state.issue_status.present? && each_pane.kanban_state.issue_status.last.id.present? && @subprojects_ids.present?
          issues = Issue.find_by_sql("select * from issues where project_id in (#{@subprojects_ids}) and status_id in (#{each_pane.kanban_state.issue_status.last.id});");
          end
          # issues=[]
          # @subprojects.each do |each_project|
          #
          # issues << each_project.issues.where(:status_id=>each_pane.kanban_state.issue_status.last.id) if each_pane.kanban_state.issue_status.present?
          # end
          #  issues.flatten!
           if issues.present?
             issues.each do |each_issue|
               # kanban_new = KanbanCard.find_or_initialize_by_issue_id_and_kanban_pane_id(each_issue.id,each_pane.id)
               kanban_new = KanbanCard.where(:issue_id=>each_issue.id,:kanban_pane_id=>each_pane.id).first_or_initialize
                 kanban_new.issue_id = each_issue.id
                 kanban_new.developer_id= each_issue.assigned_to_id
                 kanban_new.verifier_id=each_issue.assigned_to_id
                 kanban_new.kanban_pane_id=each_pane.id
                 kanban_new.save
            end
           end
           end
      end
      if  params[:kanban].present? && params[:kanban][:subproject_enable].present? && params[:kanban][:subproject_enable] == "0"

         @kanban.kanban_pane.each do |each_pane|
          @subprojects = @project.descendants.active
          # @subprojects_ids= @subprojects.map(&:id) if @subprojects.present?
          #
          # issues = KanbanPane.find_by_sql("select * from issues where project_id in (#{@subprojects_ids}) and status_id in (#{each_pane.kanban_state.issue_status.last.id});");

          @subprojects_ids = @subprojects.map(&:id).join(',') if @subprojects.present?

          issues=[]
          if each_pane.kanban_state.present? && each_pane.kanban_state.issue_status.present? && each_pane.kanban_state.issue_status.last.id.present? && @subprojects_ids.present?
            issues = Issue.find_by_sql("select * from issues where project_id in (#{@subprojects_ids}) and status_id in (#{each_pane.kanban_state.issue_status.last.id});");
          end

         # issues=[]
          # @subprojects.each do |each_project|
          # issues << each_project.issues.where(:status_id=>each_pane.kanban_state.issue_status.last.id) if each_pane.kanban_state.issue_status.present?
          # end
          #  issues.flatten!

           if issues.present?
             KanbanCard.where(:issue_id=>issues.map(&:id)).destroy_all

          end
           end

      end

      end


    respond_to do |format|
      format.json {render :nothing => true}
      format.html do
        if (params[:position])
          render :partial => "edit_js"
        else
          redirect_to settings_project_path(params[:project_id], :tab => 'Kanban')
        end
      end
    end
  end

  def edit
    @project = Project.find(params[:project_id])
    @kanban = Kanban.find(params[:id])
    @kanbans = Kanban.find_all_by_project_id(params[:project_id])
    @roles = Role.all
    if @kanbans.nil?
      @trackers = Tracker.all
    else
      used_trackers = []
      @kanbans.each {|k| used_trackers << k.tracker if k.is_valid and k.id != params[:id].to_i}
      @trackers = Tracker.all.reject {|t| used_trackers.include?(t)}
    end
  end

  def destroy
    puts params
    @kanban = Kanban.find(params[:id])
    @kanban.update_attribute(:is_valid, false);
    @saved = @kanban.save
    respond_to do |format|
      format.js do
        render :partial => "update"
      end
      format.html { redirect_to :controller => 'projects', :action => 'settings', :id => params[:project_id], :tab => 'Kanban' }
    end
  end

  # create a new kanban by copying reference.
  def copy
    ref_kanban = Kanban.find(params[:ref_id])
    ref_kanban_panes = KanbanPane.find_all_by_kanban_id(params[:ref_id])
    ref_workflow = KanbanWorkflow.find_all_by_kanban_id(params[:ref_id])

    new_kanban = ref_kanban.dup
    new_kanban.project_id = params[:project_id]
    new_kanban.update_attribute(:is_valid, true)
    new_kanban.save!
    ref_kanban_panes.each do |p|
      new_pane = p.dup
      new_pane.kanban_id = new_kanban.id
      new_pane.save!
    end

    ref_workflow.each do |w|
      new_w = w.dup
      new_w.kanban_id = new_kanban.id
      new_w.save!
    end
    redirect_to edit_project_kanban_path(new_kanban.project_id, new_kanban.id, :tab => "Panes")
  end

  def pane(pane_id)
    pane = KanbanPane.find(pane_id)
  end

  def stage(pane_id)
    pane = pane(pane_id)
    stage = Stage.find(pane.stage_id) if !pane.nil?
  end
end
