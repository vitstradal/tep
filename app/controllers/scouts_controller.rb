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

    if !(can? :show_other, Scout) || !(Scout::scout_id(current_user) == params[:id].to_i)
      render :not_allowed_to_show_others
      return
    end
  end

  def new
    if current_user.nil?
      render :log_in_to_new
      return
    elsif Scout::scouts?(current_user)
      render :show
      return
    end

    @scout = Scout.new
    @user_id = current_user.id
  end

  def create
    @scout = Scout.new(scout_params)
    @user_id = current_user.id

    if @scout.save(scout_params)
      redirect_to @scout
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @scout = Scout.find(params[:id])
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
      redirect_to user_show(params[:id])
    else
      redirect_to scouts_path
    end
  end

  private
    def scout_params
      params.require(:scout).permit! #TODO
    end
end
