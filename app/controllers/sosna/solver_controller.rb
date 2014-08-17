# encoding: utf-8
require 'ffi-locale'
class Sosna::SolverController < SosnaController

  include SosnaHelper

  def index
    load_config
    @solvers = get_sorted_solvers(@annual)
  end

  def delete
     id = params[:id]
     u = Sosna::Solver.find(id)
     if u
       u.destroy
       add_success 'řešitel smazán'
     else
       add_alert 'řešitel neexistuje'
     end
     redirect_to action: :index
  end

  def new
    load_config
    @school ||= flash[:school] || Sosna::School.new
    @solver ||= flash[:solver] 
    if ! @solver 
      @solver= _prepare_new_solver
    end
    @schools = Sosna::School.all.load
    @agree = flash[:agree] || false
  end
  #def new_tnx end

  def create
    load_config
    params.require(:sosna_solver).permit!

    school_id =  params[:school].delete :id
    send_first =  true
    send_first =  false if !current_user.nil? && current_user.admin? && params[:send_first].nil?

    solver = Sosna::Solver.new(params[:sosna_solver])


    solver.valid?
    agree = ! params[:souhlasim].nil?
    solver.errors.add(:souhlasim, 'Je nutno souhlasit s podmínkami') if ! agree
    solver.errors.add(:email, 'je již registrován u jiného řešitele') if Sosna::Solver.where(email: solver.email, annual: @annual).exists?
    solver.errors.add(:email, 'neexistující adresa') if !solver.email.empty? && !email_valid_mx_record?(solver.email)
    solver.errors.add(:birth, 'jsi příliš stár') if !solver.birth.empty? && (Date.parse(solver.birth) + 17.years) < Date.today

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
        add_alert "Pozor: ve formuláři jsou chyby"
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
      user =  User.new(email: solver.email.downcase, name: solver.name, last_name: solver.last_name, confirmation_sent_at: Time.now,  roles: [:user])
      user.confirm!
      user.send_first_login_instructions  if send_first
      solver.user_id = user.id
      user.save
    else 
      solver.user_id = user.id
    end

    # some test
    school.save if school.id.nil?
    solver.save
    redirect_to :action => :create_tnx, :send_first =>  send_first
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
  def _prepare_new_solver
    return Sosna::Solver.new if current_user.nil?
    last_solver =  Sosna::Solver.find_by_user_id(current_user.id)
    return Sosna::Solver.new(:email => current_user.email.downcase) if last_solver.nil?
    new_solver = last_solver.clone
    delta = @annual.to_i - new_solver.annual.to_i
    new_solver.grade_num = new_solver.grade_num.to_i + delta
    new_solver.grade = _grade_plus(new_solver.grade,delta)
    return new_solver
  end
  def _grade_plus(grade, delta)

    cl =  %w(nila prima sekunda tercie kvarta kvinta sexta septima oktava)
    return "#{$1}#{cl[delta+1]}#{$2}" if grade =~ /^(.*)prima(.*)$/i
    return "#{$1}#{cl[delta+2]}#{$2}" if grade =~ /^(.*)sekunda(.*)$/i
    return "#{$1}#{cl[delta+3]}#{$2}" if grade =~ /^(.*)terice(.*)$/i
    return "#{$1}#{cl[delta+4]}#{$2}" if grade =~ /^(.*)kvarta(.*)$/i
    return "#{$1}#{cl[delta+4]}#{$2}" if grade =~ /^(.*)qarta(.*)$/i
    return "#{$1}#{cl[delta+5]}#{$2}" if grade =~ /^(.*)kvinta(.*)$/i
    return "#{$1}#{cl[delta+6]}#{$2}" if grade =~ /^(.*)sexta(.*)$/i
    return "#{$1}#{cl[delta+7]}#{$2}" if grade =~ /^(.*)septima(.*)$/i
    return "#{$1}#{cl[delta+8]}#{$2}" if grade =~ /^(.*)okt.va(.*)$/i

    ro = %w( i ii iii iv v vi vii viii ix )
    if grade =~ /^([ixv]+)(.)/i
      r, rest = $1, $2
      ri = ro.index(r.downcase)
      if ! ri.nil? 
        r_plus = ro[ri+delta] 
        return "#{r_plus.upcase}#{rest}" if ! r_plus.nil?
      end
    end

    if grade =~ /^([^\d]*)(\d+)(.*)$/ 
      prefix, id, rest = $1, $2, $3
      return "#{prefix}#{id.to_i + delta}#{rest}"
    end
    return grade
  end
end
