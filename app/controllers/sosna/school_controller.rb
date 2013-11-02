class Sosna::SchoolController < SosnaController

  def show
    @school = Sosna::School.find params[:id]
  end

  def index
    @schools =  Sosna::School.all
  end

  def new
    @school  = Sosna::School.new
    render :show
  end
  def update
    params.require(:sosna_school).permit!
    sch = params[:sosna_school]
    commit = params[:commit]

    want_next =  commit =~ /Ulo.*it a dal/

    if ! sch[:id]
      # new
      school = Sosna::School.create sch
      return redirect_to action: :new if want_next
      return redirect_to action: :show, id: school.id
    end

    # update
    school = Sosna::School.find sch[:id]
    school.update_attributes sch

    return redirect :show, id: school.id if ! want_next
    redirect_to :action=> :show, :id =>  school.id + 1

  end
end
