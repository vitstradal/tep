##
# Controller pro "skauty", neboli uživatele, kteří chtějí jezdit na akce
#

class ScoutsController < ApplicationController
  def index
    @grade = params[:grade].nil? ? "ev" : params[:grade]
    @role = params[:role].nil? ? "p" : params[:role]

    if @grade == "ev"
      @scouts = Scout.all()
    else
      @scouts = Scout.where(grade: @grade)
    end

    if @role == 'p'
      @scouts = @scouts.select{ |s| ! s.org? }
    else
      @scouts = @scouts.select{ |s| s.org? }
    end
  end

  def show
    @scout = Scout.find_by(id: params[:id])

    if @scout.nil?
      render :not_found
      return
    end

    if !(can? :show_other, Scout) && !(Scout::scout_id(current_user) == params[:id].to_i)
      @msg = "Tento uživatelský účet není tvůj a bohužel nemáš práva na zobrazování účtů ostatních."
      render :not_allowed
      return
    end

    args_my_events, _ = Event::generate_sql(Scout.find(params[:id]), "ev", "yes")
    args_maybe_events, _ = Event::generate_sql(Scout.find(params[:id]), "ev", "maybe")
    args_no_events, _ = Event::generate_sql(Scout.find(params[:id]), "ev", "no")

    args_not_my_events, _ = Event::generate_sql(Scout.find(params[:id]), "ev", "nvt")
    @my_events = Event.find_by_sql(args_my_events)
    @maybe_events = Event.find_by_sql(args_maybe_events)
    @no_events = Event.find_by_sql(args_no_events)
    @not_my_events = Event.find_by_sql(args_not_my_events)
  end

  def new
    if current_user.nil?
      render :log_in_to_new
      return
    elsif Scout::scouts?(current_user) 
      redirect_to Scout::get_scout_path(current_user)
      return
    end

    @scout = Scout.new(:user_id => current_user.id, :name => current_user.name, :last_name => current_user.last_name, :email => current_user.email)
  end

  def create
    if Scout::scouts?(current_user) && (! can? :create_other, Scout)
      @msg = "Ty už svůj uživateský účet máš."
      render :not_allowed
      return
    end

    if params[:user_id] != current_user.id && (! can? :create_other, Scout)
      @msg = "Nemáš práva na vytváření uživatelských účtů ostatním užvatelům."
      render :not_allowed
      return
    end

    @scout = Scout.new(scout_params)
    @user_id = current_user.id

    agree = ! params[:souhlasim].nil?
    @scout.errors.add(:souhlasim, 'Je nutno souhlasit s podmínkami') if ! agree

    if @scout.errors.count == 0 && @scout.save(scout_params)
      redirect_to @scout
    else
      add_alert "Pozor: ve formuláři jsou chyby"
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    if ! Scout::scouts?(current_user) && params[:id] != current_user.scout.id && (! can? :update_other, Scout)
      @msg = "Nemáš práva na upravování uživatelských účtů ostatních užvatelů."
      render :not_allowed
      return
    end

    @scout = Scout.find_by(params[:id])
    if @scout.nil?
      render :not_found
      return
    end
    @user_id = @scout.user_id
  end

  def update
    if params[:user_id] != current_user.id && (! can? :update_other, Scout)
      @msg = "Nemáš práva na upravování uživatelských účtů ostatních uživatelů."
      render :not_allowed
      return
    end

    @scout = Scout.find_by(params[:id])

    if @scout.nil?
      render :not_found
      return
    end

    if @scout.update(scout_params)
      redirect_to @scout
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def confirm_delete
    if @scout.user_id != current_user.id && (! can? :delete_other, Scout)
      @msg = "Nemáš práva na mazání uživatelských účtů ostatních uživatelů."
      render :not_allowed
      return
    end

    @scout = Scout.find(params[:id])
  end

  def delete
    if @scout.user_id != current_user.id && (! can? :delete_other, Scout)
      @msg = "Nemáš práva na mazání uživatelských účtů ostatních uživatelů."
      render :not_allowed
      return
    end

    @scout = Scout.find(params[:id])
    deleting_myself = @scout.user_id == current_user.id
    @scout.destroy
    
    if deleting_myself
      redirect_to user_path(params[:id])
    else
      redirect_to scouts_path
    end
  end

  def new_user
    user =  User.new(roles: [:user])
  end

  def create_user

  end

  def new_year
    if ! current_user.admin?
      @msg = "Na zahájení nového ročníků nemáš právo."
      render :not_allowed
      return
    end

    Scout.find_each do |s|
      s.grade += 1
      s.save
    end
    redirect_to scouts_path
  end

  def previous_year
    if ! current_user.admin?
      @msg = "Na vrácení ročníků nemáš právo."
      render :not_allowed
      return
    end

    Scout.find_each do |s|
      s.grade -= 1
      s.save
    end
    redirect_to scouts_path
  end

  private
    def scout_params
      params.require(:scout).permit! #TODO
    end
end
