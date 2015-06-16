require 'nkf'
class TimelogImportInProgres < ActiveRecord::Base
  unloadable
  belongs_to :user
  belongs_to :project

  before_save :encode_csv_data
  validates_presence_of :csv_data
  #validates_attachment_content_type :csv_data, :content_type =&gt; ['text/csv','text/comma-separated-values','text/csv','application/csv','application/excel','application/vnd.ms-excel','application/vnd.msexcel','text/anytext','text/plain']

  private
  def encode_csv_data
    return if self.csv_data.blank?

    self.csv_data = self.csv_data
    # 入力文字コード
    encode = case self.encoding
               when "U"
                 "-W"
               when "EUC"
                 "-E"
               when "S"
                 "-S"
               when "N"
                 ""
               else
                 ""
             end

    self.csv_data = NKF.nkf("#{encode} -w", self.csv_data)
  end
end
