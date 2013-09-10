# encoding: utf-8
require 'pp'
#require 'rubygems'
require 'zip'

class SosnaSolutionController < SosnaController

  UPLOAD_DIR = "public/uploads"
  def index
      @solutions = SosnaSolution.all
  end

  def download
    # XXX auth!
    solution = SosnaSolution.find id = params[:id]
    #dir = '/home/vitas/vs/pia/'
    #send_file dir + solution.filename, :type =>  "application/pdf"
    send_file solution.filename, :type => 'application/pdf'
  end

  def show
      @solution = SosnaSolution.find params[:id]
  end

  def downall
    solutions = SosnaSolution.all
    zip_file_name = UPLOAD_DIR + '/solutions-all.zip' 
    print "downall\n"

    Zip::File.open(zip_file_name, Zip::File::CREATE) do |zipfile|
      solutions.each do |solution|
        # Two arguments:
        # - The name of the file as it will appear in the archive
        # - The original file, including the path to find it
        filename = solution.filename
        print pp(solution)
        next if filename.nil? 
        zipfile.add('reseni/' + filename,  filename)
      end
    end
    send_file zip_file_name, :type => "application/zip"
  end

  def user_upload
    solution_file = params[:sosna_solution][:solution_file]
    solution_id  = params[:sosna_solution][:id]

    return redirect_to :sosna_user_solutions if solution_file.nil?

    print "content type:", solution_file.content_type
    if solution_file.original_filename !~ /\.pdf$/
      flash[:errors] = {:pozor => 'pouze soubory ve formátu .pdf'}
      return redirect_to :action => :user_index
    end

    # find solution
    solution = SosnaSolution.find(solution_id) or raise RuntimeError, "bad solution id: #{solution_id}"
    problem, solver  = solution.sosna_problem, solution.sosna_solver
    pp problem
    pp solver

    # save file
    filename = UPLOAD_DIR + "/solution-roc%02i-ser%02i-ul%i-sol%i-%s-%s.pdf"  %
                  [ problem.annual, problem.round, problem.problem_no,
                    solver.id, solver.name, solver.last_name ]
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

    @solver = SosnaSolver.where(:user_id => current_user.id).first
    if ! @solver
       flash[:errors] = {:pozor => 'zatím nejsi řešitelem, nejprve vyplň přihlašku!'}
       return redirect_to :controller => :sosna_solver , :action => :new
    end

    problem_ids = @problems.map { |p| p.id }
    @solutions = id_problem_hash(SosnaSolution.find(:all,  :conditions => {
                                          :sosna_solver_id => @solver.id,
                                          :sosna_problem_id => problem_ids,
                                         }))

    #logger.fatal "fatal:" + @solutions.inspect
    @problems.each do |p|
      #logger.fatal "fatal2:" + @solutions.inspect
      if ! (@solutions.has_key?(p.id))
        @solutions[p.id] = SosnaSolution.create({
                                            :sosna_solver_id => @solver.id,
                                            :sosna_problem_id => p.id,
                                            })
      end
    end
  end
end
