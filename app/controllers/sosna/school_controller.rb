# encoding: utf-8
class Sosna::SchoolController < SosnaController

  include ApplicationHelper

  def show
    @school = Sosna::School.find params[:id]
  end

  def index
    @schools =  Sosna::School.all.load
    @shorts = {}
    @schools.each do  |sch|
      if @shorts[sch.short].nil?
        @shorts[sch.short] = 1
      else
        @shorts[sch.short] += 1
      end
       
    end
    respond_to do |format|
      format.html
      format.pik do
         headers['Content-Disposition'] = "attachment; filename=skoly-roc#{@annual}.pik"
         headers['Content-Type'] = "text/plain; charset=UTF-8";
      end
    end
  end

  def delete
     id = params[:id]
     u = Sosna::School.find(id)
     if u
       u.destroy
       add_success 'škola smazana'
     else
       add_alert 'no such škola'
     end
     redirect_to action: :index
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

    return redirect_to :action => :show, :id =>  school.id if ! want_next
    redirect_to :action=> :show, :id =>  school.id + 1

  end
end
