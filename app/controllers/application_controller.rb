class ApplicationController < ActionController::Base
  authorize_resource
  protect_from_forgery
end
