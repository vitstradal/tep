require 'pp'
class PiaController < ApplicationController

  def index; end
  #authorize_resource :class => false

  def users
    @users = User.all
  end

  def user_role_change
    user = User.find params[:user][:id];
    add, role  = params[:role].split //, 2

    if User.valid_roles.include? role.to_sym
      case add
      when '+'
        user.roles << role
      when '-'
        user.roles.delete role
      end
      user.save
      print pp user
    else
      print pp User.valid_roles
      print 'no role', role
    end
    redirect_to :users_list
  end
end
