module TimeEntryFlexiPatch
  def self.included(base)
    base.extend(ClassMethods)

    base.send(:include, InstanceMethods)

    base.class_eval do

      # validates :flexioff_reason, :presence => true
      # before_save :check_flexioff
    before_save :shiva,:shivareddy
    before_create :shiva,:shivareddy
    before_update :shivareddy
p self
      def self.shiva

p 99999999999999999999999999999999999999999999999999999
      end
      def shivareddy

p 777777777777777777777777
      end


      # def condition_testing?
      #   p 99999999999999999999999999999999999999999999999
      #   activity.name == 'Flexi OFF' if activity.present?
      #
      # end
      # def check_flexioff
      #   p "++++++++++++++++++hellooo========================="
      #   p 8888888888888888888888888888888888888888888888888888
      #
      #
      #   self.flexioff_reason= nil if self.flexioff_reason==''
      # end


    end
  end

  module ClassMethods; end

  module InstanceMethods; end




end




