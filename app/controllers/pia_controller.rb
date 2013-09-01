require 'pp'
class PiaController < ApplicationController

  before_filter do
    case action_name.to_sym

     when :index 
             authorize! :anon, :pia

     when :users, :user_role_change
             authorize! :admin, :pia

     else
       authorize! nil, nil
    end
  end

  def index
    render
  end
  def hello
    render
  end
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
