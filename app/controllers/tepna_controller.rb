class TepnaController < ApplicationController
  include ApplicationHelper

  ##
  #  GET  /tepna/info
  #
  #  return render :json => {
  #    status: 'ok',
  #    solver_name: "vitas",
  #    message: nil,
  #    annual: 36,
  #    rounds: [ { 
  #      ound: 1,
  #      problems: [
  #          { name: "uloha 1", id: "505050" },
  #          { name: "uloha 1", id: "505050" }
  #      ]
  #  }]
  def info
    authorize! :info, :tepna
    load_config
    solver = Sosna::Solver.where(annual: @annual, user_id: current_user.id).first
    if solver.nil?
      return render json: {  status: 'ko', message: 'Nepřihlášený řešitel' }
    end
    problems  = Sosna::Problem.where(:annual=> @annual, :round=> @round).all 
    solutions_by_problem = {}
    Sosna::Solution.where(:solver_id => solver.id, :problem_id => problems.map{|p|p.id}).each do |solution|
      solutions_by_problem[solution.problem_id] = solution
    end
    return render json: {
      status: 'ok',
      solver_name: solver.full_name,
      message: nil,
      annual: @annual,
      rounds: [ { 
        round: @round,
        deadline: @config["deadline#{@round}".to_sym],
        problems: problems.map{|p|
          solution = solutions_by_problem[p.id]
          {
            name: p.title,
            id: solution.id,
            solved:  ! solution.filename.nil?
          }
        },
      }]
    }
  end
  def debug
      error = params[:error]
      user = params[:user] || 'xxx'
      ts = Time.now.strftime('%Y-%m-%d_%H:%M:%S')
      dir = 'var/tepna-dbg/'
      File.open("#{dir}/#{ts}-#{user}.log.err", 'w') { |file| file.write(error) }
      render json: {status: 'ok'}
  end
end
