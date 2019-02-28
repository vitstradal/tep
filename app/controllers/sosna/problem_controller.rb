# encoding: utf-8
class Sosna::ProblemController < SosnaController

  include ApplicationHelper

  ##
  #  GET /sosna/problems
  #
  # *Provides*
  # @problems:: pole příkladů, setřízene od nejnovějšího
  def index
      @problems = Sosna::Problem.order('annual desc, round desc,  problem_no asc').load
  end

  ##
  #  GET /sosna/problem/(:id)
  #
  # *Param*
  # id:: id příkladů
  #
  # *Provides*
  # @problem:: příklad
  def show
    @problem = Sosna::Problem.find_or_new(params[:id])
    logger.fatal "id #{@problem.id}"
  end

  ##
  #  POST /sosna/problem/(:id)
  #
  # *Params*
  # id:: id příkladu
  # *Redirects*: index
  def delete
     id = params[:id]
     u = Sosna::Problem.find(id)
     if u
       u.destroy
       add_success 'Uloha smazána'
     else
       add_alert 'no such uloha'
     end
     redirect_to action: :index
  end

  ##
  #  POST /sosna/problem/new_round
  #
  # *Params* 
  # annual:: ročník
  # round::  série
  # count::  počet příkladů v séríí
  # *Redirects*: index
  def new_round
     annual = params[:annual]
     round = params[:round]
     count = params[:count].to_i
     (1..count).each do |problem_no|
        Sosna::Problem.create({ :annual => annual,
                              :round => round,
                              :problem_no => problem_no,
                              :title => "Úloha č. #{problem_no}",
                              })
     end
     redirect_to :action => :index
  end

  ##
  #  POST /sosna/problem/update
  #
  # *Params* 
  # sosna_problem:: 
  # commit:: po update edituj další příkad
  # *Redirects*: index
  def update
    params.require(:sosna_problem).permit!
    p = params[:sosna_problem]
    commit = params[:commit]
    if p[:id]
      problem = Sosna::Problem.find p[:id]
      problem.update_attributes p
    else
      problem = Sosna::Problem.create p
    end

    if commit =~ /Ulo.*it a dal/
       redirect_to :action=> :show, :id => problem.id + 1
    else 
       redirect_to :action=> :show, :id => problem.id
    end
  end
end
