class CasTokenController < ApplicationController
  unloadable

  def check_token
    current_url = "http://#{request.host+request.fullpath}"
    if current_url.present? && current_url.include?('?ticket=')
      p session
      redirect_to "/"
    end
  end

end
