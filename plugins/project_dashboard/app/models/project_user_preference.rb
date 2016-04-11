class ProjectUserPreference < ActiveRecord::Base
  # unloadable
  belongs_to :user
  belongs_to :project
  has_many :overdue_unmanage_tasks_settings
  serialize :others
  serialize :save_text_editor
  acts_as_attachable
  attr_protected :others, :user_id,:project_id

  before_save :set_others_hash

  def self.project_user_preference(user_id,project_id)
    project_preference = self.find_or_initialize_by_project_id_and_user_id(:user_id=>user_id,:project_id=>project_id)
    project_preference.user_id=user_id
    project_preference.project_id=project_id
    return project_preference
  end

  def initialize(attributes=nil, *args)
    super
    self.others ||= {}
  end

  def set_others_hash
    self.others ||= {}
  end

  def [](attr_name)
    if has_attribute? attr_name
      super
    else
      others ? others[attr_name] : nil
    end
  end

  def []=(attr_name, value)
    if has_attribute? attr_name
      super
    else
      h = (read_attribute(:others) || {}).dup
      h.update(attr_name => value)
      write_attribute(:others, h)
      value
    end
  end

  def comments_sorting; self[:comments_sorting] end
  def comments_sorting=(order); self[:comments_sorting]=order end

  def warn_on_leaving_unsaved; self[:warn_on_leaving_unsaved] || '1'; end
  def warn_on_leaving_unsaved=(value); self[:warn_on_leaving_unsaved]=value; end

  def no_self_notified; (self[:no_self_notified] == true || self[:no_self_notified] == '1'); end
  def no_self_notified=(value); self[:no_self_notified]=value; end

  # Callback on file attachment
  def attachment_added(obj)
    if @current_journal && !obj.new_record?
      @current_journal.details << JournalDetail.new(:property => 'attachment', :prop_key => obj.id, :value => obj.filename)
    end
  end
end
