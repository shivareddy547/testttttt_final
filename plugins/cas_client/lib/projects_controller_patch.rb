module ProjectsControllerPatch
  def self.included(base)
    base.class_eval do
     

      before_filter :require_login



    end
    end
end
