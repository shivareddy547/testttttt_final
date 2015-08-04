class CasTokenController < ApplicationController
  unloadable


  def index
    current_url = "http://#{request.host+request.fullpath}"
   if current_url.present? && current_url.include?('?ticket=')

   redirect_to "/projects"

   end

end

end
