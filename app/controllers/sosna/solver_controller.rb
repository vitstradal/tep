# encoding: utf-8
class Sosna::SolverController < SosnaController

  include SosnaHelper

  def index
      @solvers = Sosna::Solver.all
  end

  def delete
     id = params[:id]
     u = Sosna::Solver.find(id)
     if u
       u.destroy
       add_success 'řešitel smazán'
     else
       add_alert 'no such řešitel'
     end
     redirect_to action: :index
  end

  def new
    load_config
    @school ||= flash[:school] || Sosna::School.new
    @solver ||= flash[:solver] 
    if ! @solver 
      @solver= Sosna::Solver.new(:email => current_user.nil? ? nil : current_user.email )
    end
    @schools = Sosna::School.all
    @agree = flash[:agree] || false
  end
  #def new_tnx end

  def create
    load_config
    params.require(:sosna_solver).permit!

    school_id =  params[:school].delete :id


    solver = Sosna::Solver.new(params[:sosna_solver])

    solver.valid?
    agree = ! params[:souhlasim].nil?
    solver.errors.add(:souhlasim, 'Je nutno souhlasit s podmínkami') if ! agree
    solver.errors.add(:email, 'je již registrován u jiného řešitele') if Sosna::Solver.find_by_email(solver.email)

    case school_id
     when 'none' 
       solver.errors.add(:skola, 'Vyber školu ze seznamu nebo zadej novou')
     when 'jina' 
      params.require(:sosna_school).permit!
      school = Sosna::School.new(params[:sosna_school])
     else
      school = Sosna::School.find(school_id)
    end

    if school.nil? || school.invalid? || solver.errors.count > 0
        school.id = -1 if school_id == 'jina'
        flash[:solver] = solver
        flash[:school] = school
        flash[:agree] = agree
        Rails.logger.fatal(pp("school", solver.errors.messages))
        Rails.logger.fatal(pp("solver", school.errors.messages)) if school
        return redirect_to :action => :new
    end

    solver.school = school
    solver.annual = @annual

    user = User.find_by_email solver.email
    if !user 
      # create user by email
      user =  User.new(email: solver.email, name: solver.name, last_name: solver.last_name, confirmation_sent_at: Time.now,  roles: [:user])
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
    @solver = id ? Sosna::Solver.find(id) : Sosna::Solver.new
    @school = @solver.school
    new
  end

  def update
    params.require(:sosna_solver).permit!
    sr = params[:sosna_solver]
    school_id =  params[:school].delete :id

    begin
      school = Sosna::School.find(school_id) 
    rescue
      params.require(:sosna_school).permit!
      school = Sosna::School.new(params[:sosna_school])
      school.save
    end

    if sr[:id]
      solver = Sosna::Solver.find(sr[:id])
      solver.school = school
      solver.update_attributes(sr)
    else
      solver = Sosna::Solver.create(sr)
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
