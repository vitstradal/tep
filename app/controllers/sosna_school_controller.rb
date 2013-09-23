class SosnaSchoolController < SosnaController

  def show
    @school = SosnaSchool.find params[:id]
  end

  def index
    @schools =  SosnaSchool.all
  end

  def new
    @school  = SosnaSchool.new
    render :show
  end
  def update
    sch = params[:sosna_school]
    commit = params[:commit]

    want_next =  commit =~ /Ulo.*it a dal/

    if ! sch[:id]
      # new
      school = SosnaSchool.create sch
      return redirect_to action: :new if want_next
      return redirect_to action: :show, id: school.id
    end

    # update
    school = SosnaSchool.find sch[:id]
    school.update_attributes sch

    return redirect :show, id: school.id if ! want_next
    redirect_to :action=> :show, :id =>  school.id + 1

  end
end
