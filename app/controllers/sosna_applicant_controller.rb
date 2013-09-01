class SosnaApplicantController < SosnaController

  def index
      @applicants = SosnaApplicant.all
  end

  def new
    load_config
    @schools = SosnaSchool.all
    @school = flash[:school] || SosnaSchool.new
    @applicant = flash[:applicant] 
    @applicant ||= SosnaApplicant.new(:email => current_user.nil? ? nil : current_user.email )
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

    applicant = SosnaApplicant.new(params[:sosna_applicant])
    applicant.sosna_school = school
    print pp applicant
    if applicant.invalid?
        flash[:errors] = applicant.errors
        flash[:applicant] = applicant
        flash[:school] = school
        return redirect_to :action => :new
    end

    user = User.find_by_email applicant.email
    if user 
        applicant.user_id = user.id
    else
        # create user by email
    end


    # some test
    school.save
    applicant.save
    redirect_to :action => :create_tnx
  end
  def create_tnx
  end

  def show
    id = params[:id]
    @applicant = id ? SosnaApplicant.find(id) : SosnaApplicant.new
  end

  def update
    a = params[:sosna_applicant]
    if a[:id]
      problem = SosnaApplicant.find(p[:id])
      problem.update_attributes(p)
    else
      problem = SosnaApplicant.create(p)
    end
    redirect_to :show
  end
end
