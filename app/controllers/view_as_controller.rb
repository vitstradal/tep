##
# Přepínač „jak to vidí“ (viz ApplicationController::VIEW_AS_ROLES)
class ViewAsController < ApplicationController
  def update
    level = params[:view_as]
    if view_as_switch? && VIEW_AS_ROLES.key?(level)
      session[:view_as] = level
    else
      session.delete(:view_as)
    end
    redirect_back fallback_location: root_path
  end

  def toggle
    if view_as_allowed? && !session[:view_as_switch]
      session[:view_as_switch] = true
    else
      session.delete(:view_as_switch)
      session.delete(:view_as)
    end
    redirect_back fallback_location: root_path
  end
end
