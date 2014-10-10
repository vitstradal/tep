class ApplicationController < ActionController::Base
  protect_from_forgery
  rescue_from CanCan::AccessDenied do |exception|
      #sign_out :user
      redirect_to :access_denied
  end
  include ApplicationHelper

  def after_sign_in_path_for(resource)
     ret =  url_for_root(resource)
     Rails::logger.fatal("url:#{ret}");
     return ret
  end

end
