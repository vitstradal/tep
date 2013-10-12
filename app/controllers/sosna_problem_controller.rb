# encoding: utf-8
class SosnaProblemController < SosnaController

  def index
      @problems = SosnaProblem.order('annual desc, round desc,  problem_no asc')
                              .all
  end

  def show
    @problem = SosnaProblem.find_or_new(params[:id])
    logger.fatal "id #{@problem.id}"
  end

  def new_round
     annual = params[:annual]
     round = params[:round]
     count = params[:count].to_i
     (1..count).each do |problem_no|
        SosnaProblem.create({ :annual => annual,
                              :round => round,
                              :problem_no => problem_no,
                              :title => "Úloha č. #{problem_no}",
                              })
     end
     redirect_to :action => :index
  end

  def update
    params.require(:sosna_problem).permit!
    p = params[:sosna_problem]
    commit = params[:commit]
    if p[:id]
      problem = SosnaProblem.find p[:id]
      problem.update_attributes p
    else
      problem = SosnaProblem.create p
    end

    if commit =~ /Ulo.*it a dal/
       redirect_to :action=> :show, :id => problem.id + 1
    else 
       redirect_to :action=> :show, :id => problem.id
    end
  end
end
