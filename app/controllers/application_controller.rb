class ApplicationController < ActionController::Base
  protect_from_forgery

  include ApplicationHelper

  def after_sign_in_path_for(resource)
     ret = params[:next] || url_for_root(resource)
     log("after_sign_in_path_for:#{ret}, next: #{params[:next]}");
     return ret
  end

  rescue_from StandardError do |exception|
    _error(exception)
  end

  rescue_from CanCan::AccessDenied do |exception|
      if current_user.nil?
        redirect_to new_user_session_url(:next => request.path)
      else
        _error(exception)
      end
  end

  def _error(exception)
    @errid = "ERR-#{rand(1000000)}"
    @error = "#{exception}"
    log "#{@errid}: #{@error}"

    Tep::Mailer.error(errid: @errid,
                      action: @_action_name,
                      error: @error,
                      timestamp: DateTime.now.strftime("%y-%m-%d %H:%M:%S"),
                      email: current_user.nil? ? nil : current_user.email,
                      params: params.to_hash,
                      host: request.remote_ip,
                      useragent: request.user_agent,
                      backtrace: exception.backtrace,
                    ).deliver_later
    render :layout => nil, template: 'tep/error'
  end

end
