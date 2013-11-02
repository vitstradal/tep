# encoding: utf-8
require 'pp'
#require 'rubygems'
require 'zip'
require 'tempfile'

class Sosna::SolutionController < SosnaController

  UPLOAD_DIR = "public/uploads/"

  def index
    @solutions = _solutions_from_roc_se_ul
    _load_index
  end
  def edit
    @solutions = _solutions_from_roc_se_ul
    @want_edit = true
    render :index
  end

  def update_scores
    roc, se, ul = params[:roc], params[:se], params[:ul]
    scores = params[:score]

    pp scores
    scores.each_with_index do |(sol_id, score), idx|

      print "xxx:#{score},#{sol_id}"
      sol = Sosna::Solution.find(sol_id)
      sol.score = score
      sol.save
    end


    redirect_to action: :edit, roc: roc, se: se, ul: ul
  end

  def _load_index
    @want_edit = false
    @solutions = _solutions_from_roc_se_ul
    path = [ _annual_link(@annual) ]

    dir = nil

    if @problem_no
      # in level problem
      path.push(_round_link(@annual, @round))
      path.push(_problem_link(@annual, @round, @problem_no))
      path[-1][:sub] = _problems_roc_se(@annual, @round)
      path[-1][:btn] = _problem_edit_btn(@annual, @round, @problem_no)
    elsif @round
      # in level round
      path.push(_round_link(@annual, @round))
      path[-1][:sub] = _rounds_roc(@annual)

      dir = _problems_roc_se(@annual, @round)
    else
      # in level annual
      @annuals = _annuals
      dir = _rounds_roc(@annual)
    end
    @breadcrumb = dir.nil? ? [path] : [ path, dir ]
  end

  def download_corr
    solution = Sosna::Solution.find id = params[:id]
    filename = solution.filename_corr_display
    if ! solution
      flash[:errors] = {:chyba => 'soubor neexistuje'}
      return redirect_to :action =>  :user_index 
    end

    if solution.owner? current_user
      # owner: check if it allowed to download
      if @config[:show_revisions] != 'yes' && solution.problem.round.to_s == @round && solution.problem.annual.to_s == @annual
        flash[:errors] = {:chyba => 'soubor neexistuje'}
        return redirect_to :action =>  :user_index 
      end
    else
      # may be org
      authorize! :download_org, Sosna::Solution
      filename = solution.filename_corr
    end
    send_file UPLOAD_DIR + solution.filename_corr, :filename => filename, :type => 'application/pdf'
  end

  def download

    solution = Sosna::Solution.find id = params[:id]
    filename = solution.filename_orig
    if ! solution.owner? current_user
      authorize! :download_org, Sosna::Solution
      filename = solution.filename
    end

    send_file UPLOAD_DIR + solution.filename, :filename => filename, :type => 'application/pdf'
  end

#  def show
#      @solution = Sosna::Solution.find params[:id]
#  end

  def downall
    solutions = _solutions_from_roc_se_ul

    zip_file = Tempfile.new(['solution', '.zip'], UPLOAD_DIR)
    zip_file_name = zip_file.path
    zip_file.unlink

    # Zip::File.open potrebuej aby zip_file_naem (neexistovalo
    # jinak si zacne myslet, ze zip chci otevrit a ne prepsat
    # naopak Tempfile nedokaze jen vymyslet jmeno a neotevirat
    Zip::File.open(zip_file_name, Zip::File::CREATE) do |zipfile|
      solutions.each do |solution|
        filename = solution.filename
        next if filename.nil?
        zipfile.add('reseni/' + File.basename(filename),  UPLOAD_DIR + filename)
      end
    end
    send_file zip_file_name, :filename => 'reseni.zip', :type => "application/zip"
    #File.delete zip_file_name 
  end

  def upload_corr
    cfile = params[:file_corr]
    roc = params[:roc]
    se =  params[:se]
    ul =  params[:ul]

    # reseni-roc29-se01-ul2-rel001-ori-vitas-vitas.pdf
    # reseni-roc29-se01-ul2-rel001-rev-vitas-vitas.pdf
    cfile_name = cfile.original_filename
    if cfile_name =~ /\.pdf$/
       path =  _upload_corr_one(roc, se, ul,  cfile_name)
       if path
         print "writing to path"
         File.open(UPLOAD_DIR + path, 'wb') {  |f| f.write(cfile.read) }
       end
    elsif cfile.original_filename =~ /\.zip$/
       zip_file = Tempfile.new(['corr', '.zip'], UPLOAD_DIR)
       File.open(zip_file, 'wb') {  |f| f.write(cfile.read) }
       zip_file.close
       Zip::File.open(zip_file.path) do |zipfile|
         zipfile.each do |entry|
           path =  _upload_corr_one(roc, se, ul,  entry.name)
           if path
             entry.extract(UPLOAD_DIR + path)  { true }
           end
         end
       end
    else
      _add_msg(cfile_name, nil)
    end
    redirect_to :action =>  :index, :roc => roc, :se => se, :ul => ul
  end

  def _add_msg(fname, msg, success = false)
    if success
      flash[:success] = {fname => msg}
    else
      flash[:errors] = {fname => msg}
    end
    print "msg: #{fname}: #{msg}\n"
  end

  def _upload_corr_one(roc, se, ul,  fname)

    if fname !~ /^reseni-roc(\d+)-se(\d+)-ul(\d+)-rel(\d+)-(ori|rev)-.*.pdf/
      _add_msg(fname, "jmeno souboru neni ve spravnem formatu '#{fname}'")
      return nil
    end
    oroc, ose, oul, relid = $1.to_i, $2.to_i, $3.to_i, $4.to_i

    if oroc.to_s != roc || ose.to_s != se || oul.to_s != ul
       _add_msg(fname, "reseni neni ke spravnemu rocniku, serii, uloze")
      return nil
    end

    solver = Sosna::Solver.find(relid)
    if !solver
       _add_msg(fname, "neexistuje takovy resitel #{relid}")
       return nil
    end

    problem = Sosna::Problem.where(:annual => roc, :round => se, :problem_no => ul).take
    solution = Sosna::Solution.where( :problem_id => problem.id, :solver_id => solver.id).take

    filename_corr = _sol_filename( roc, se, ul, solver.id, solver.name, solver.last_name, true)
    solution.filename_corr = filename_corr
    solution.filename_corr_display =  _filename_corr_display(solution.filename_orig)
    solution.save

    print "solution id: #{solution.id}, #{solution.filename_corr}\n"
    _add_msg(fname, "ok", true)
    return filename_corr

  end

  def _filename_corr_display(orig)
      orig.sub(/(\.[^\.]+)$/, '-opraveno\1')
  end

  def upload
    solution_file = params[:sosna_solution][:solution_file]
    solution_id  = params[:sosna_solution][:id]

    return redirect_to :sosna_solutions_user if solution_file.nil?

    print "content type:", solution_file.content_type
    if @config[:allow_upload] != 'yes'
      flash[:errors] = {:pozor => 'pouze soubory ve formátu .pdf'}
      return redirect_to :action => :user_index
    end
    if solution_file.original_filename !~ /\.pdf$/
      flash[:errors] = {:pozor => 'pouze soubory ve formátu .pdf'}
      return redirect_to :action => :user_index
    end

    # find solution
    solution = Sosna::Solution.find(solution_id) or raise RuntimeError, "bad solution id: #{solution_id}"

    if !solution.owner? current_user
        authorize! :upload_org, Sosna::Solution
    end

    problem, solver  = solution.problem, solution.solver
    pp problem
    pp solver

    # save file
    filename = _sol_filename(  problem.annual, problem.round, problem.problem_no,
                              solver.id, solver.name, solver.last_name)

    File.open(UPLOAD_DIR + filename, 'wb') {  |f| f.write(solution_file.read) }


    # update solution
    solution.filename = filename
    solution.filename_orig = solution_file.original_filename
    solution.save

    redirect_to :action => :user_index
  end

  def user_index
    #load_config
    @annual = params[:roc] || @config[:annual]
    @round  = params[:se]  || @config[:round]
    @breadcrumb = [[], _rounds_roc(@annual, @round) ]

    @is_current = (@annual == @config[:annual] && @round ==  @config[:round])

    die if current_user.nil?

    @problems  = Sosna::Problem.where(:annual=> @annual, :round=> @round)

    @solver = Sosna::Solver.where(:user_id => current_user.id).first
    if ! @solver
       flash[:errors] = {:pozor => 'zatím nejsi řešitelem, nejprve vyplň přihlašku!'}
       return redirect_to :controller => :solver , :action => :new
    end

    problem_ids = @problems.map { |p| p.id }
    @solutions = id_problem_hash(Sosna::Solution.find(:all,  :conditions => {
                                          :solver_id => @solver.id,
                                          :problem_id => problem_ids,
                                         }))

    #logger.fatal "fatal:" + @solutions.inspect
    @problems.each do |p|
      #logger.fatal "fatal2:" + @solutions.inspect
      if ! (@solutions.has_key?(p.id))
        @solutions[p.id] = Sosna::Solution.create({
                                            :solver_id => @solver.id,
                                            :problem_id => p.id,
                                            })
      end
    end
  end

  private

  def _params_roc_se_ul
    roc, se, ul = params[:roc],  params[:se], params[:ul]
    load_config

    if roc.nil? && se.nil?
        roc  = @annual
        se  = @round
    end

    @annual = roc
    @round = se
    @problem_no = ul 

    return roc, se, ul
  end

  def _solutions_from_roc_se_ul
    roc, se, ul = _params_roc_se_ul
    if ul
      return Sosna::Solution.joins(:problem).where(:sosna_problems => {:annual => roc, :round => se, :problem_no => ul}).load
    else
      return Sosna::Solution.joins(:problem).where(:sosna_problems => {:annual => roc, :round => se}).load
    end
  end

  def _problems_roc_se(roc, se)
      return Sosna::Problem.where({:annual => roc, :round => se})
                         .load
                         .map do |ul|
                              _problem_link(@annual, @round, ul.problem_no)
                         end

  end

  # return Sosna::Problem
  def _rounds_roc(roc, se = nil)
    rounds = []
    Sosna::Problem.select('round')
                       .where({annual: roc})
                       .group('round')
                       .order('round')
                       .load
                       .each do |pr|
                          rounds.push  _round_link(roc, pr.round, pr.round.to_s == se)
                       end
    rounds
  end

  def _annual_link(annual)
     {name: "Ročník #{annual}", url: {roc:@annual}}
  end

  def _problem_link(annual, round, problem_no)
      {name: "Úloha #{problem_no}", url: {roc: annual, se: round, ul: problem_no}}
  end

  def _problem_edit_btn(annual, round, problem_no)
      {name: "Editovat", url: {action: 'edit', roc: annual, se: round, ul: problem_no}}
  end

  def _round_link(annual, round, active= false)
     {name: "Série #{round}", active: active, url: {roc: annual, se: round}}
  end

  def _annuals
    annual = {}
    Sosna::Problem.select('annual')
                       .group('annual')
                       .order('annual desc')
                       .load
                       .each do |a|
                            annual[a.annual] = _rounds_roc(a.annual)
                       end
    return annual
  end

  def _sol_filename(roc, se, ul, rel_id, name, last, is_corr=  false)
     typ = is_corr ? 'rev' : 'ori'
     'reseni-roc%02i-se%02i-ul%i-rel%03i-%s-%s.pdf'  % [ roc, se, ul, rel_id, typ, name, last ]
  end


end
