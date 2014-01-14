# encoding: utf-8
require 'pp'
require 'fileutils'
#require 'rubygems'
require 'zip'
require 'tempfile'

class Sosna::SolutionController < SosnaController

  include SosnaHelper
  include ActionView::Helpers::NumberHelper 
  UPLOAD_DIR = "public/uploads/"

  def index
    _solutions_from_roc_se_ul_by_solver
    _load_index
    respond_to do |format|
      format.html
      format.csv do
         ul = @problem_no.nil? ?  '' : "-ul#{@problem_no}"
         headers['Content-Disposition'] = "attachment; filename=lidi-roc#{@annual}-se#{@round}#{ul}.csv"
      end
      format.pik do
         ul = @problem_no.nil? ?  '' : "_#{@problem_no}"
         headers['Content-Disposition'] = "attachment; filename=body#{@annual}_#{@round}#{ul}.pik"
         headers['Content-Type'] = "text/plain; charset=UTF-8";
      end
    end  

  end
  def edit
    _solutions_from_roc_se_ul_by_solver
    @want_edit = true
    render :index
  end

  def update_scores
    roc, se, ul = params[:roc], params[:se], params[:ul]
    scores = params[:score]
    paper = params[:paper] || {}
    solutions = Sosna::Solution.find(scores.keys)

    solutions.each do |sol|

      id = sol.id.to_s

      score = begin Integer scores[id] ; rescue ; nil ;  end
      has_paper_mail = paper.has_key? id

      if sol.score != score || sol.has_paper_mail != has_paper_mail
        sol.score = score
        sol.has_paper_mail = has_paper_mail
        sol.save
      end
    end

    redirect_to action: :edit, roc: roc, se: se, ul: ul
  end

  def _load_index
    @want_edit = false
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
      path[-1][:btn] = _problem_edit2_btn(@annual, @round)

      dir = _problems_roc_se(@annual, @round)
    else
      # in level annual
      @annuals = _annuals
      dir = _rounds_roc(@annual)
    end
    @breadcrumb = dir.nil? ? [path] : [ path, dir ]
  end

  def download_rev
    solution = Sosna::Solution.find id = params[:id]
    if ! solution
      add_alert 'Chyba: soubor neexistuje'
      return redirect_to :action =>  :user_index 
    end

    if solution.owner? current_user
      # owner: check if it allowed to download
      round = solution.problem.round
      sol_in_this_round_allowed   = round <  @config[:round] 
      sol_in_this_round_allowed ||= round == @config[:round] && @config[:show_revisions] == 'yes'
      if ! sol_in_this_round_allowed
        add_alert 'Chyba: soubor neexistuje'
        return redirect_to :action =>  :user_index 
      end
      filename = solution.filename_corr_display
      filename_disp = solution.filename_corr_display
    else
      # may be org
      authorize! :download_org, Sosna::Solution
      filename = solution.filename_corr
      filename_disp = solution.get_filename_rev
    end
    send_file UPLOAD_DIR + solution.filename_corr, :filename => filename_disp, :type => 'application/pdf'
  end

  def download

    solution = Sosna::Solution.find id = params[:id]
    filename = solution.filename_orig
    filename_disp = solution.filename_orig
    if ! solution.owner? current_user
      authorize! :download_org, Sosna::Solution
      filename = solution.filename
      filename_disp = solution.get_filename_ori
    end

    send_file UPLOAD_DIR + solution.filename, :filename => filename_disp, :type => 'application/pdf'
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
        filename_disp = solution.get_filename_ori
        next if filename.nil?
        zipfile.add('reseni/' + File.basename(filename_disp),  UPLOAD_DIR + filename)
      end
    end
    send_file zip_file_name, :filename => 'reseni.zip', :type => "application/zip"
    #File.delete zip_file_name 
  end

  def upload_rev
    rfile = params[:file_rev]
    roc = params[:roc]
    se =  params[:se]
    ul =  params[:ul]

    # reseni-roc29-se01-ul2-rel001-ori-vitas-vitas.pdf
    # reseni-roc29-se01-ul2-rel001-rev-vitas-vitas.pdf
    cfile_name = rfile.original_filename
    if cfile_name =~ /\.pdf$/
       path =  _upload_rev_one(roc, se, ul,  cfile_name)
       if path
         print "writing to path"
         File.open(UPLOAD_DIR + path, 'wb') {  |f| f.write(rfile.read) }
       end
    elsif rfile.original_filename =~ /\.zip$/
       zip_file = Tempfile.new(['corr', '.zip'], UPLOAD_DIR)
       File.open(zip_file, 'wb') {  |f| f.write(rfile.read) }
       zip_file.close
       Zip::File.open(zip_file.path) do |zipfile|
         zipfile.each do |entry|
           path =  _upload_rev_one(roc, se, ul,  entry.name)
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
      add_success "#{fname}: #{msg}"
    else
      add_alert "#{fname}: #{msg}"
    end
    #print "msg: #{fname}: #{msg}\n"
  end

  def _upload_rev_one(roc, se, ul,  fname)

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

    #filename_corr = _solution_filename(problem, solver, true)
    filename_rev = solution.get_filename_rev
    solution.filename_corr = filename_rev
    solution.filename_corr_display =  _filename_rev_display(solution.filename_orig)
    solution.save

    print "solution id: #{solution.id}, #{solution.filename_corr}\n"
    _add_msg(fname, "ok", true)
    return filename_corr

  end

  def _filename_rev_display(orig)
      orig.sub(/(\.[^\.]+)$/, '-opraveno\1')
  end

  def upload
    solution_file = params[:sosna_solution][:solution_file]
    solution_id  = params[:sosna_solution][:id]

    # find solution
    solution = Sosna::Solution.find(solution_id) or raise RuntimeError, "bad solution id: #{solution_id}"
    if !solution
      add_alert "Špatné číslo řešení"
      return redirect_to :action => :user_index
    end
    problem, solver  = solution.problem, solution.solver
    se = problem.round
    roc = problem.annual

    if problem.annual.to_s != @config[:annual] || deadline_time(@config, problem.round) < Time.now
      pp solution.problem.annual != @config[:annual]
      pp @config[:annual]
      pp solution.problem.annual
      pp deadline_time(@config, solution.problem.round)
      add_alert "Řešení není možné odevdat"
      return redirect_to :action => :user_index, roc: roc, se: se
    end

    if !solution.owner? current_user
        authorize! :upload_org, Sosna::Solution
    end

    if solution_file.nil?
      solution.filename = nil
      solution.filename_orig = nil
      solution.save
      add_success "Soubor smazán"
      return redirect_to :action => :user_index, roc: roc, se: se
    end

    if solution_file.original_filename !~ /\.pdf$/
      add_alert 'Pozor: pouze soubory ve formátu PDF'
      return redirect_to :action => :user_index, roc: roc, se: se
    end

    max_size =  Rails.configuration.sosna_user_solution_max_size || (20 * 1024 * 1024)
    if solution_file.size > max_size
      add_alert "Soubor je příliš velký (větší než #{number_to_human_size max_size})."
      return redirect_to :action => :user_index, roc: roc, se: se
    end


#    pp problem
#    pp solver
#
    # save file
    filename = solution.get_filename_ori
    File.open(UPLOAD_DIR + filename, 'wb') {  |f| f.write(solution_file.read) }

    sign_pdf(solution, UPLOAD_DIR + filename)

    # update solution
    solution.filename = filename
    solution.filename_orig = solution_file.original_filename
    solution.save
    add_success 'Soubor úspěšně nahrán'
    redirect_to :action => :user_index, roc: roc, se: se
  end


  def sign_pdf(solution, dest)
      problem = solution.problem
      solver = solution.solver
      name = "#{solver.last_name} #{solver.name}"
      ulfull = "roč#{problem.annual} se#{problem.round} ul#{problem.problem_no}"

      template = dest + '.tmpl'
      FileUtils::cp  dest, template

      begin
        Prawn::Document.generate(dest, :template => template) do
          # hack utf8 font
          font_families.update( 'andulka' => { :normal => 'public/stylesheets/andulka/andulkabook-webfont.ttf' } )
          font 'andulka' 
          repeat( :all, :dynamic => true ) do
                      draw_text "#{ulfull} #{name}", :at => bounds.top_left
                      draw_text "str#{page_number}/#{page_count.to_s}", :at => bounds.top_right
          end
        end
      rescue Exception => e  
        Rails::logger.fatal("Hlavicka fail: #{e.to_s}")
        FileUtils::cp template, dest 
      end
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
       add_alert "Pozor: zatím nejsi řešitelem, nejprve vyplň přihlašku!"
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

  def _solutions_from_roc_se_ul_by_solver
    load_config
    @solvers = get_sorted_solvers(@annual)
    @solutions = _solutions_from_roc_se_ul
    @problems =  _problems_from_roc_se_ul
    @solutions_by_solver = []

    numbers = {}
    
    @solutions.each do |sol|
      solver_id = sol.solver_id
      problem_no = sol.problem.problem_no

      @solutions_by_solver[solver_id] ||= []
      @solutions_by_solver[solver_id][problem_no] =  sol

      numbers[problem_no] = 1
    end
    @solvers.each do |solver|
      @solutions_by_solver[solver.id] ||= []
      @problems.each do |pr|
        if @solutions_by_solver[solver.id][pr.problem_no].nil? 
          sol = Sosna::Solution.create({ :solver_id => solver.id, :problem_id => pr.id, })
          @solutions_by_solver[solver.id][pr.problem_no] = sol
        end
      end
    end

  end
  def _problems_from_roc_se_ul
    roc, se, ul = _params_roc_se_ul
    if ul
      return Sosna::Problem.where(:annual => roc, :round => se, :problem_no => ul).load
    else
      return Sosna::Problem.where(:annual => roc, :round => se).load
    end
  end

  def _solutions_from_roc_se_ul
    roc, se, ul = _params_roc_se_ul
    if ul
      return Sosna::Solution.includes(:problem).joins(:problem).where(:sosna_problems => {:annual => roc, :round => se, :problem_no => ul}).load
    else
      return Sosna::Solution.includes(:problem).joins(:problem).where(:sosna_problems => {:annual => roc, :round => se}).load
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

  def _problem_edit2_btn(annual, round)
      {name: "Editovat", url: {action: 'edit', roc: annual, se: round }}
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




end
