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
    school_id =  params[:school].delete :id

    begin
      school = SosnaSchool.find(school_id) 
    rescue
      school = SosnaSchool.new(params[:sosna_school])
      school.id = -1 if school_id == 'jina'
    end

    solver = SosnaSolver.new(params[:sosna_solver])
    solver.sosna_school = school
    print pp solver
    if solver.invalid?
        flash[:errors] = solver.errors
        flash[:solver] = solver
        flash[:school] = school
        return redirect_to :action => :new
    end

    user = User.find_by_email solver.email
    if user 
        solver.user_id = user.id
    else
        # create user by email
    end


    # some test
    school.save
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
      solver = SosnaSolver.create(srp)
    end
    redirect_to :show
  end
end