class RejectLockedReportsController < ApplicationController
  unloadable
  before_filter :find_project

  def index
    @unlocks = []
    @project = Project.find(params[:project_id])
    @trackers  = @project.trackers
    @members  = @project.users
    @to= Date.today
    @from=(Date.today-30)
    #@rejections = @project.rejections.order('date desc') if @project.rejections
    @rejections = Rejection.where(:project_id => @project.id,:date => (@from.to_date)..(@to.to_date))
    @rejections = @rejections.order('date desc') if @rejections
    @members.each do |each_member|
      @unlocks << UserUnlockHistory.where(:user_id=>each_member.id,:created_at => (@from.to_date)..(@to.to_date))
    end

    @unlocks = @unlocks.flatten.sort!{|a,b|b.date <=> a.date} if @unlocks.present?
    @messages = []

    params[:tabs]="reject_report"
    #redirect_to settings_project_path(@project, :tab => 'default_assignee')
  end
  def result
    @unlocks=[]
    get_project_with_period
    if params[:user_id] == "All"

      @rejections = Rejection.where(:project_id => @project.id,:date => (@from.to_date)..(@to.to_date))
      @rejections = @rejections.order('date desc') if @rejections
    else
      user_id=params[:user_id] if params[:user_id].present?
      @rejections = Rejection.where(:project_id => @project.id,:user_id=>user_id,:date => (@from.to_date)..(@to.to_date))
      @rejections = @rejections.order('date desc') if @rejections
    end
    get_member_unlocks

    headers = ["ID", "User", "Rejected By", "Rejected Date", "Comment"]
    rejections_report_csv = CSV.generate do |csv|
      csv << headers
      @rejections.each do |reject|
        #csv<< unlock.attributes.values_at(*column_names)
        csv << [reject.id, reject.user, reject.rejected_user, reject.date,reject.comment]
      end
    end
    respond_to do |format|
      format.csv do
        send_data(rejections_report_csv, :type => 'text/csv', :filename => 'RejectionsReport.csv')
      end
      format.html do
        render :index
      end

    end
    #render :index
  end



  def unlocked_report

    @unlocks=[]
    get_project_with_period
    get_project_member_rejections
    #get_member_unlocks

    if params[:user_id] == "All"
      @members  = @project.users
      @members.each do |each_member|
        @unlocks << UserUnlockHistory.where(:user_id=>each_member.id,:created_at => (@from.to_date)..(@to.to_date))
      end
      @unlocks = @unlocks.flatten.sort!{|a,b|b.date <=> a.date} if @unlocks.present?
    else
      user_id=params[:user_id] if params[:user_id].present?
      #project= params[:project_id]
      #@rejections = Rejection.where(:project_id => @project.id,:user_id=>user_id,:date => (@from.to_date)..(@to.to_date))
      @unlocks = UserUnlockHistory.where(:user_id=>params[:user_id],:created_at => (@from.to_date)..(@to.to_date))
      @unlocks = @unlocks.flatten.sort!{|a,b|b.date <=> a.date} if @unlocks.present?
    end
    headers = ["ID", "User", "Unlocked By(manager)", "Date", "Comment"]
    unlocked_report_csv = CSV.generate do |csv|
      csv << headers
      @unlocks.each do |unlock|
      #csv<< unlock.attributes.values_at(*column_names)
        csv << [unlock.id, unlock.user, unlock.unlocked_user, unlock.date,unlock.comment]
      end
    end
    respond_to do |format|
      format.csv do
        send_data(unlocked_report_csv, :type => 'text/csv', :filename => 'UnlockedReport.csv')
      end
      format.html do
        render :index
      end

    end
  end


  def get_project_member_rejections
    #@members  = @project.users
    @rejections = Rejection.where(:project_id => @project.id,:date => (@from.to_date)..(@to.to_date))
    @rejections = @rejections.order('date desc') if @rejections
  end

  def get_member_unlocks
    @members  = @project.users
    @members.each do |each_member|
      @unlocks << UserUnlockHistory.where(:user_id=>each_member.id)
    end
    if @unlocks.present?
    @unlocks = @unlocks.flatten.sort!{|a,b|b.date <=> a.date} if @unlocks.present?
      end
  end



  def get_project_with_period
    @project = Project.find(params[:project_id])
    check_from = params[:from].to_date rescue nil
    check_to = params[:to].to_date rescue nil
    if params[:from].present? && check_from.present?

      @month = params[:from].split('/')[0]
      @date = params[:from].split('/')[1]
      @year =  params[:from].split('/')[2]
      @from = Date.new(@year.to_i,@month.to_i,@date.to_i).to_date if params[:from].present?
    else
      @from = (Date.today-30)
    end
    if !params[:user_id].present?
      params[:user_id] = "All"
    end

    if  params[:to].present? && check_to.present?
      @month1 = params[:to].split('/')[0]
      @date1 = params[:to].split('/')[1]
      @year1 =  params[:to].split('/')[2]
      @to = Date.new(@year1.to_i,@month1.to_i,@date1.to_i).to_date if params[:to].present?
    else
      @to = (Date.today)
    end

  end

  private

  def find_project

    #params[:project_id] = 1
    @project = Project.find(params[:project_id])
  end

end
