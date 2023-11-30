##
# Controller pro "skauty", neboli uživatele, kteří chtějí jezdit na akce
#

class Act::ScoutsController < ActController
  def index
    @grade = params[:grade].nil? ? "ev" : params[:grade]
    @role = params[:role].nil? ? "p" : params[:role]

    case @grade
    when "ev"
      @scouts = Act::Scout.all()
    when "young"
      @scouts = Act::Scout.find_by_sql(["SELECT * FROM act_scouts WHERE grade < ?", Act::Scout::YOUNGEST_TO_FILTER])
    when "old"
      @scouts = Act::Scout.find_by_sql(["SELECT * FROM act_scouts WHERE grade > ?", Act::Scout::OLDEST_TO_FILTER])
    else
      @scouts = Act::Scout.where(grade: @grade)
    end

    if @role == 'p'
      @scouts = @scouts.select{ |s| ! s.org? }
    else
      @scouts = @scouts.select{ |s| s.org? }
    end
  end

  def show
    @scout = Act::Scout.find_by(id: params[:scout_id])

    if @scout.nil?
      render :not_found
      return
    end

    if !(can? :show_other, Act::Scout) && !(Act::Scout::scout_id(current_user) == params[:id].to_i)
      @msg = "Tento uživatelský účet není tvůj a bohužel nemáš práva na zobrazování účtů ostatních."
      render :not_allowed
      return
    end

    args_my_events, _ = Act::Event::generate_sql(Act::Scout.find(params[:scout_id]), "ev", "yes")
    args_maybe_events, _ = Act::Event::generate_sql(Act::Scout.find(params[:scout_id]), "ev", "maybe")
    args_no_events, _ = Act::Event::generate_sql(Act::Scout.find(params[:scout_id]), "ev", "no")
    args_not_my_events, _ = Act::Event::generate_sql(Act::Scout.find(params[:scout_id]), "ev", "nvt")

    @my_events = Act::Event.find_by_sql(args_my_events)
    @maybe_events = Act::Event.find_by_sql(args_maybe_events)
    @no_events = Act::Event.find_by_sql(args_no_events)
    @not_my_events = Act::Event.find_by_sql(args_not_my_events)
  end

  def new
    if current_user.nil?
      render :log_in_to_new
      return
    elsif Act::Scout::scouts?(current_user) 
      redirect_to Act::Scout::get_scout_path(current_user)
      return
    end

    @scout = Act::Scout.new(:user_id => current_user.id, :name => current_user.name, :last_name => current_user.last_name, :email => current_user.email)
  end

  def create
    if Act::Scout::scouts?(current_user) && (! can? :create_other, Act::Scout)
      @msg = "Ty už svůj uživateský účet máš."
      render :not_allowed
      return
    end

    if params[:scout][:user_id] != current_user.id.to_s && (! can? :create_other, Act::Scout)
      @msg = "Nemáš práva na vytváření uživatelských účtů ostatním užvatelům."
      render :not_allowed
      return
    end

    @scout = Act::Scout.new(scout_params)
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
    if current_user.nil? || ((! Act::Scout::scouts?(current_user) || (Act::Scout::scouts?(current_user) && params[:id] != current_user.scout.id.to_s)) && (! can? :update_other, Act::Scout))
      @msg = "Nemáš práva na upravování uživatelských účtů ostatních užvatelů."
      render :not_allowed
      return
    end

    @scout = Act::Scout.find_by(params[:id])
    if @scout.nil?
      render :not_found
      return
    end
    @user_id = @scout.user_id
  end

  def update
    if current_user.nil? || (params[:user_id] != current_user.id && (! can? :update_other, Act::Scout))
      @msg = "Nemáš práva na upravování uživatelských účtů ostatních uživatelů."
      render :not_allowed
      return
    end

    @scout = Act::Scout.find_by(params[:id])

    if @scout.nil?
      render :not_found
      return
    end

    @scout.activated = true

    if @scout.update(scout_params)
      redirect_to @scout
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def confirm_delete
    @scout = Act::Scout.find(params[:scout_id])
    if current_user.nil? || (@scout.user_id != current_user.id && (! can? :delete_other, Act::Scout))
      @msg = "Nemáš práva na mazání uživatelských účtů ostatních uživatelů."
      render :not_allowed
      return
    end
  end

  def delete
    @scout = Act::Scout.find(params[:scout_id])
    if current_user.nil? || (@scout.user_id != current_user.id && (! can? :delete_other, Act::Scout))
      @msg = "Nemáš práva na mazání uživatelských účtů ostatních uživatelů."
      render :not_allowed
      return
    end

    deleting_myself = @scout.user_id == current_user.id
    @scout.destroy
    
    if deleting_myself
      redirect_to user_show_path(params[:scout_id])
    else
      redirect_to scouts_path
    end
  end

  def new_user
    user =  Act::User.new(roles: [:user])
  end

  def create_other
    if ! can? :create_other, Act::Scout
      @msg = "Na vytváření uživetských účtů ostatním uživatelům nemáš práva."
      render :not_allowed
      return
    end

    user = Act::User.find(params[:user_id])
    scout = Act::Scout.new(:user_id => user.id, :name => user.name, :last_name => user.last_name, :email => user.email, :activated => false)
    scout.save(validate: false)
    redirect_to params[:path]
  end

  def new_year
    if current_user.nil? || ! current_user.admin?
      @msg = "Na zahájení nového ročníků nemáš právo."
      render :not_allowed
      return
    end

    Act::Scout.find_each do |s|
      s.grade += 1
      s.save
    end
    redirect_to scouts_path
  end

  def previous_year
    if current_user.nil? || ! current_user.admin?
      @msg = "Na vrácení ročníků nemáš právo."
      render :not_allowed
      return
    end

    Act::Scout.find_each do |s|
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
