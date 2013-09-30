# encoding: utf-8
class SosnaSolverController < SosnaController


  def index
      @solvers = SosnaSolver.all
  end

  def new
    load_config
    @schools = SosnaSchool.all
    @school = flash[:school] || SosnaSchool.new
    @solver ||= flash[:solver] 
    @solver ||= SosnaSolver.new(:email => current_user.nil? ? nil : current_user.email )
  end
  #def new_tnx end

  def create
    load_config
    school_id =  params[:school].delete :id

    begin
      school = SosnaSchool.find(school_id) 
    rescue
      school = SosnaSchool.new(params[:sosna_school])
    end

    solver = SosnaSolver.new(params[:sosna_solver])

    if SosnaSolver.find_by_email solver.email
      flash[:errors] = {email: 'je již registrován u jiného řešitele'}
      flash[:solver] = solver
      flash[:school] = school
      return redirect_to :action => :new
    end

    solver.sosna_school = school
    solver.annual = @annual
    print pp solver
    if solver.invalid?
        school.id = -1 if school_id == 'jina'
        flash[:errors] = solver.errors
        flash[:solver] = solver
        flash[:school] = school
        return redirect_to :action => :new
    end

    user = User.find_by_email solver.email
    if !user 
      # create user by email
      user =  User.new(email: solver.email, roles: [:user])
      user.confirm!
      user.send_first_login_instructions
      solver.user_id = user.id
      user.save
    else 
      solver.user_id = user.id
    end

    # some test
    school.save if school.id.nil?
    solver.save
    redirect_to :action => :create_tnx
  end

  def create_tnx
  end

  def show
    id = params[:id]
    @solver = id ? SosnaSolver.find(id) : SosnaSolver.new
    new
  end

  def update
    sr = params[:sosna_solver]
    if sr[:id]
      solver = SosnaSolver.find(sr[:id])
      solver.update_attributes(sr)
    else
      solver = SosnaSolver.create(sr)
    end
    redirect_to :action =>  :show , :id => solver.id
  end
  def _send_user_auto_creation_instructions(user)
       #user.send_confirmation_instructions
       user.generate_confirmation_token! if user.confirmation_token.nil?
       #user.devise_mailer.confirmation_instructions(user).deliver
       devise_mailer.devise_mail(user, :confirmation_instructions).deliver

  end
end
