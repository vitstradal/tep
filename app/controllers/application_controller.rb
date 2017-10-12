class ApplicationController < ActionController::Base
  protect_from_forgery
  rescue_from CanCan::AccessDenied do |exception|
      if current_user.nil?
        redirect_to new_user_session_url(:next => request.path)
      else
        @error = "#{exception}"
        error
      end
      log('application-controller-rescue')
  end

  def error
    log('application-controller-error')
    @errid = "ERR-#{rand(1000000)}"
    if @error
      log "#{@errid}: #{@errror}"
    else
      log "#{@errid}"
    end
    render :layout => nil, template: 'tep/error'
  end

  include ApplicationHelper

  def after_sign_in_path_for(resource)
     ret = params[:next] || url_for_root(resource)
     log("after_sign_in_path_for:#{ret}, next: #{params[:next]}");
     return ret
  end

end
