# encoding: utf-8
class Sosna::SchoolController < SosnaController

  include ApplicationHelper

  ##
  #  GET /sosna/school/:id/show
  #
  # zobrazí školu
  #
  # *Params*
  # id:: id školy
  #
  # *Provides*
  # @school:: daná škola
  # @solver_count_by_annual:: hash, klíč ročníky, hodnota počet řešitelů v tomto ročníku z této školy
  def show
    @school = Sosna::School.find params[:id]
    @solver_count_by_annual = Sosna::Solver.where( school_id: params[:id]).group(:annual).count 
  end

  ##
  #  GET /sosna/schools.fmt
  #
  # *Formats*
  # html:: 
  # pik:: csv
  # *Provides*
  # @schools:: pole škol
  # @schools_solver_count:: poček škol v současném ročníku
  # @izos:: hash škol, klíč je `univerzal_id` (aka izo)
  # @shorts:: hash škol, klíč je `short`
  def index
    @schools =  Sosna::School.all.load
    @schools_solver_count = Sosna::Solver.where(annual: @annual).group(:school_id).count
    @shorts = {}
    @izos= {}
    @schools.each do  |sch|
      if @izos[sch.universal_id].nil?
        @izos[sch.universal_id] = 1
      else
        @izos[sch.universal_id] += 1
      end
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

  ##
  #  POST /sosna/school/:id/delete
  #
  # smaže školu
  #
  # *Params*
  # id: id školy
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

  ##
  #  POST /sosna/school/new
  #
  # nová škola
  #
  # *Params*
  # id: id školy
  #
  # *Provides*
  # @school nová škola bez parametrů
  def new
    @school  = Sosna::School.new
    render :show
  end

  ##
  #  POST /sosna/school/update
  #
  # aktualizace 
  #
  # *Params*
  # school[]: aktualizované údaje
  # commit:: pokud je 'Uložit next' bude po aktualizace zobrazna následující škola
  #
  # *Redirect*"  show
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
