# encoding: utf-8
require 'pp'
class TepController < ApplicationController

  include ApplicationHelper


  def pokusy; end
  def index;
    if ! current_user.nil?
      if current_user.has_role? :admin
        return redirect_to(wiki_main_path(path: 'org'))
      elsif current_user.has_role? :org
        return redirect_to(wiki_main_path(path: 'org'))
      elsif current_user.has_role? :user
        return redirect_to(wiki_main_path(path: 'user'))
      end
    end
    redirect_to(wiki_main_path(path: 'index'))
  end

  authorize_resource :class => false
  def faq; end

  def users
    @users = User.all.load
    #print 'sign:', sign("ahoj")
  end

  def user
    @user = User.find(params[:id])
  end

  def user_delete
     id = params[:id]
     u = User.find(id)
     if u
       u.destroy
       add_success 'Uživatel smazán'
     else
       add_alert 'uživatel neexistuje'
     end
     redirect_to action: :users
  end

  def user_action
    user_id = params[:id]
    user = User.find(user_id)
    case params[:what]

      when 'send_first_email'
        user.send_first_login_instructions
        add_success 'Posláno'

      when 'send_password_reset'
        user.send_reset_password_instructions
        add_success 'Posláno'

      else
        add_alert 'Bad luck'
    end
    redirect_to action: :user, id: user_id
  end

  def user_update
    params.require(:user).permit!
    user_id = params[:id]
    user = User.find(user_id)
    if user
      user.update(params[:user])
      add_success 'Data aktualizovaná'
    end
    redirect_to action: :user, id: user_id
  end

  def user_finish_registration
      token = params[:token]
      @user = User.find_by_reset_password_token(token)
      #print "user:", pp(@user)
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
      #print pp user
    else
      print pp User.valid_roles
      print 'no role', role
    end
    #redirect_to :users_list
    redirect_to(user_show_path(id: user.id))
  end
end
