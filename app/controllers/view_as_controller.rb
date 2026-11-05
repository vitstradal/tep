##
# Přepínač „jak to vidí“ (viz ApplicationController::VIEW_AS_ROLES)
class ViewAsController < ApplicationController
  def update
    level = params[:view_as]
    if view_as_allowed? && VIEW_AS_ROLES.key?(level)
      session[:view_as] = level
    else
      session.delete(:view_as)
    end
    redirect_back fallback_location: root_path
  end
end
