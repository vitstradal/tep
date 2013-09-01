# encoding: utf-8
require 'pp'

class SosnaSolutionController < SosnaController

  def index
      @solutions = SosnaSolution.all
  end

  def show
      @solution = SosnaSolution.find param[:id]
  end

  def user_upload
    solution_file = params[:sosna_solution][:solution_file]
    solution_id  = params[:sosna_solution][:id]

    return redirect_to :sosna_solutions if solution_file.nil?

    # find solution
    solution = SosnaSolution.find(solution_id) or raise RuntimeError, "bad solution id: #{solution_id}"
    problem, applicant  = solution.sosna_problem, solution.sosna_applicant
    pp problem
    pp applicant

    # save file
    filename = "public/uploads/solution-a%02i-r%02i-p%i-a%i-%s.ext"  %
                  [ problem.annual, problem.round, problem.problem_no,
                    applicant.id, applicant.name ]
    File.open(filename, 'wb') {  |f| f.write(solution_file.read) }


    # update solution
    solution.filename = filename
    solution.orig_filename = solution_file.original_filename
    solution.save

    redirect_to :action => :user_index
  end

  def user_index
    # fixme: from db
    load_config

    die if current_user.nil?

    @problems  = SosnaProblem.where(:annual=>@config[:annual], :round=>@config[:round])

    @applicant = SosnaApplicant.where(:user_id => current_user.id).first
    if ! @applicant
       flash[:errors] = {:pozor => 'zatím nejsi řešitelem, nejprve vyplň přihlašku!'}
       return redirect_to :controller => :sosna_applicant , :action => :new
    end

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
end
