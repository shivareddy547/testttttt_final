require 'csv'
# require 'iconv'
class NcMaster < ActiveRecord::Base
  # attr_accessible :name, :time_in_a_day, :type, :value_of_day
  attr_accessible :nc_id, :nc_type,:process_id, :title, :description, :severity, :responsibility, :accountability, :ofs_qms, :qms_version, :isms_version, :document_version, :version


  def self.import_csv
    csv_text = File.read('nc_master.csv')
    csv = CSV.parse(csv_text, :headers => true)
    csv.each do |row|

      NcMaster.create!(row.to_hash)
    end

  end
end
