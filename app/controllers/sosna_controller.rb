class SosnaController < ApplicationController

  def index
    if user_signed_in? 
      @applicant = SosnaApplicant.where({:user_id => current_user.id})
      if @applicant
         @problems = SosnaProblem.where({:year => 2013, :round => 1})
      end
    end
  end

  def problems
    @problems = SosnaProblem.all
  end

  def problem
    id = params[:id]
    if id 
      @problem = SosnaProblem.find(id)
    else
      @problem = SosnaProblem.new
    end
    logger.fatal "id #{@problem.id}"
  end 


  def problem_save
    p = params[:sosna_problem]
    if p[:id]
      problem = SosnaProblem.find(p[:id])
      problem.update_attributes(p)
    else
      problem = SosnaProblem.create(p)
    end
    redirect_to :action=> 'problem', :id => problem.id
  end


  def solution_save
    solution_file = params[:sosna_solution][:solution_file]
    solution_id  = params[:sosna_solution][:id]

    return redirect_to :sosna_solutions if solution_file.nil?

    # find solution
    solution = SosnaSolution.find(solution_id) or raise RuntimeError, "bad solution id: #{solution_id}"
    problem, applicant  = solution.sosna_problem, solution.sosna_applicant

    # save file
    filename = "public/uploads/solution-y%04i-r%02i-p%i-a%i-%s.ext"  %
                  [ problem.year, problem.round, problem.problem_no,
                    applicant.id, applicant.name ]
    File.open(filename, 'wb') {  |f| f.write(solution_file.read) }


    # update solution
    solution.filename = filename
    solution.orig_filename = solution_file.original_filename
    solution.save

    redirect_to :sosna_solutions

  end
  def solutions
    # fixme: from db
    @year = 2013
    @round = 1

    @problems  = SosnaProblem.where(:year=>@year, :round=>@round)
    @applicant = SosnaApplicant.where(:user_id => current_user.id).first

    die if current_user.nil?

    @applicant ||= SosnaApplicant.create({:name => current_user.email,  :user_id => current_user.id})
    problem_ids = @problems.map { |p| p.id }
    @solutions = id_problem_hash(SosnaSolution.find(:all,  :conditions => {
                                          :sosna_applicant_id => @applicant.id,
                                          :sosna_problem_id => problem_ids,
                                         }))

    #logger.fatal "fatal:" + @solutions.inspect
    @problems.each do |p|
      #logger.fatal "fatal2:" + @solutions.inspect
      if ! (@solutions.has_key?(p.id))
        @solutions[p.id] = SosnaSolution.create({
                                            :sosna_applicant_id => @applicant.id,
                                            :sosna_problem_id => p.id,
                                            })
      end
    end
  end

  def id_problem_hash(arr)
    ret = {}
    arr.each { |item|  ret[item.sosna_problem_id] = item }
    #logger.fatal "hash:" + ret.inspect
    return ret
  end
end
