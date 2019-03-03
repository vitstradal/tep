# encoding: utf-8
require 'pp'
class TepController < ApplicationController

  include ApplicationHelper
  authorize_resource :class => false

  ##
  #  GET  /access
  #
  # asi obsolete
  def access; end

  ##
  # *OBSOLETE*
  def index;
    if ! current_user.nil?
      if current_user.has_role? :admin
        return redirect_to(wiki_piki_path(path: 'org'))
      elsif current_user.has_role? :org
        return redirect_to(wiki_piki_path(path: 'org'))
      elsif current_user.has_role? :user
        return redirect_to(wiki_main_path(path: 'user'))
      end
    end
    redirect_to(wiki_main_path(path: 'index'))
  end


  ##
  #  GET  /faqold
  #
  # FIXME: asi obsolete kdo vi
  def faq; end

  ##
  #  GET /users
  # 
  # seznam uživatelů
  # *Params*
  # role:: filtruj jen uživatelé s rolí
  #
  # *Provides*
  # @role::
  # @users:: pole User
  def users
    @role = params[:role] 
    if @role
       mask = User.mask_for @role.to_sym
       @users = User.where('roles_mask & ? > 0', mask)
    else
      @users = User.all.load
    end
    
  end

  ##
  #  GET /user/:id/show(/:tab)
  #
  # *Params*
  # id:: id uživatele
  # tab:: který tab se má zobrazit: `config`, `group`, `solver`, `mail`,  `jabber`
  #
  # *Profides*
  # @tab::
  # @user:: User
  # @solvers:: pole řešitelů (Sosna::Solver), kteří jsou přílsušní k uživateli
  def user
    user_id = params[:id]
    @tab = params[:tab] || 'config'
    @user = User.find(user_id);
    @solvers = Sosna::Solver.where(user_id: user_id)
  end

  ##
  #  POST /user/new
  #
  # Nový uživatel.
  #
  # *Params*
  # email::
  #
  # *Redirect* /user/:id
  def user_new
    email = params[:email] || "example#{rand(1000)}@example.com"
    user =  User.new(email: email, name: 'John', last_name: 'Smith', confirmation_sent_at: Time.now,  roles: [:user])
    user.confirm
    user.save
    redirect_to :action => :user, :id =>  user.id
  end

  ##
  #  POST  /user/:id/delete
  #
  # smaže uživatele
  #
  # *Params*
  # id:: id uživatele
  #
  # *Redirect* /users
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

  ##
  #  POST /user/:id/action/:what
  #
  # *Params*
  # id:: id uživatele
  # what:: co se má udělat
  #        send_first_email:: znova se pošle uvítací dopis
  #        send_password_reset:: reset hesla a zaslání linku na reset
  #
  # *Reditect* /user/:id
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

  ##
  #  PATCH /user/:id/update
  #
  # *Params*
  # id:: id uživatele
  # user[]:: aktualizovaná data
  #
  # *Redirect* /user/:id
  def user_update
    params.require(:user).permit!
    user_id = params[:id]
    user = User.find(user_id)
    if user
      rv = user.update(params[:user]) 
      if rv
        add_success 'Data aktualizovaná'
      else
        add_alert "Chyba aktualizace: #{pp(user.errors.messages)}"
      end
    end
    redirect_to action: :user, id: user_id
  end

  ##
  #  GET  /reg/:token
  #
  # Tento link, .
  #
  # *Params*
  # token:: token, je zaslá
  #
  # *Provides*
  # @token:: token
  # @user:: uživatel, který má tento resetovací token
  def user_finish_registration
      @token = params[:token]
      @user = User.with_reset_password_token(@token)
  end

  ##
  #  GET /die
  #
  # Pro ladící učely, vyvolá chybu dělení nulou.
  def die 
    0/0
  end

  ##
  #  PATCH /user/:id/role
  #
  # Přidá nebo odebre uživateli grupu.
  #
  # *Params*
  # id:: id uživatele
  # role:: kterou roli (skupinu), kterou přidat/odebrat
  #
  # *Redirect* /user/:id
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
