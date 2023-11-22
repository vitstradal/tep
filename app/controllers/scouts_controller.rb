##
# Controller pro "skauty", neboli uživatele, kteří chtějí jezdit na akce
#

class ScoutsController < ApplicationController
  def index
    @scouts = Scout.all()
  end

  def show
    @scout = Scout.find_by(id: params[:id])

    if @scout.nil?
      render :not_found
      return
    end

    if !(can? :show_other, Scout) && !(Scout::scout_id(current_user) == params[:id].to_i)
      render :not_allowed_to_show_others
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
    @scout = Scout.find(params[:id])
    @user_id = @scout.user_id
  end

  def update
    @scout = Scout.find(params[:id])

    if @scout.update(scout_params)
      redirect_to @scout
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def confirm_delete
    @scout = Scout.find(params[:id])
  end

  def delete
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

  private
    def scout_params
      params.require(:scout).permit! #TODO
    end
end
