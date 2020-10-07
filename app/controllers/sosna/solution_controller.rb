# encoding: utf-8
require 'pp'
require 'fileutils'
require 'zip'
require 'tempfile'
require 'combine_pdf'

class Sosna::SolutionController < SosnaController

  include ApplicationHelper
  include ActionView::Helpers::NumberHelper

  UPLOAD_DIR = "var/uploads/"

  ##
  #  GET  /sosna/solutions(/:roc(/:se(/:ul)))
  #
  # *Params*
  # roc:: ročník, pokud není vezme se aktuální
  # se:: série, pokud není vezme se aktuální
  # ul:: úloha
  # sous:: pokud se má filtrovat na sous
  #
  # *Provides*
  # @breadcrumb::
  # @want_edit::
  # @want_edit_paper::
  # @want_edit_penalisation::
  # @solvers:: pole Sosna::Solver
  # @problems:: pole Sosna::Problem
  # @solutions_by_solver:: hash solver_id => pole Sosna::Solution
  # @penalisations_by_solver:: hash solver.id => Sosna::Problem
  # @results_by_solver:: hash solver.id => Sosna::Result
  def index
    _prepare_solvers_problems_solutions(want_test: true)
    _load_index
  end

  ##
  #  GET  /sosna/solutions/rocnik/:roc
  #
  # *Params*
  # roc:: ročník, pokud není vezme se aktuální
  #
  # *Provides*
  # @breadcrumb::
  # @want_edit::
  # @want_edit_paper::
  # @want_edit_penalisation::
  # @solvers:: pole Sosna::Solver
  # @problems:: pole Sosna::Problem
  # @solutions_by_solver:: hash solver_id => pole Sosna::Solution
  # @penalisations_by_solver:: hash solver.id => Sosna::Problem
  # @results_by_solver:: hash solver.id => Sosna::Result
  def rocnik
    _prepare_solvers_problems_solutions(want_test: true)
    results = Sosna::Result.where( :annual => @annual).load
    @results_by_solver_round = {}
    results.each do |result| 
      @results_by_solver_round[result.solver_id] ||= {}
      @results_by_solver_round[result.solver_id][result.round] = result
    end
    @rounds = _rounds_roc(@annual)
  end


  ##
  #  GET  /sosna/solutions/lidi(/:roc(/:se(/:ul)))
  #
  # export seznamu lidí, format `csv`, `pik`.
  #
  # *Params*
  # roc, se, ul:: ročník, série, úloha, pokud není vezme se aktuální
  #
  # *Provide*
  # @solvers, @problems, @solutions_by_solver, @penalisations_by_solver, @results_by_solver:: jako `index`
  #
  # *Template*
  # * app/views/sosna/solution/lidi.csv.erb
  # * app/views/sosna/solution/lidi.pik.erb
  def lidi
    _prepare_solvers_problems_solutions(want_test: false)
    # dirty hack
    _sort_solvers_by_grade
    respond_to do |format|
      format.csv do
         headers['Content-Disposition'] = "attachment; filename=lidi-roc#{@annual}-se#{@round}.csv"
      end
      format.pik do
         headers['Content-Disposition'] = "attachment; filename=body#{@annual}_#{@round}.pik"
         headers['Content-Type'] = "text/plain; charset=UTF-8";
      end
    end
  end

  ##
  #  GET  /sosna/solutions/vysl(/:roc(/:se(/:ul)))
  #
  # export seznamu lidí `.pik`.
  #
  # *Params*
  # roc, se, ul:: ročník, série, úloha, pokud není vezme se aktuální
  #
  # *Provide*
  # @solvers, @problems, @solutions_by_solver, @penalisations_by_solver, @results_by_solver:: jako `index`
  #
  # *Template* app/views/sosna/solution/vysl_pik.erb
  def vysl_pik
    roc, se, ul = _params_roc_se_ul
    if ! _results_updated?(roc, se)
      add_alert 'Výsledky nejsou aktuální, použij "Generuj výsledky"'
      return redirect_to sosna_solutions_org_path(roc, se);
    end
    _prepare_solvers_problems_solutions(want_test: false, want_bonus: false)
    _sort_solvers_by_rank
    headers['Content-Disposition'] = "attachment; filename=vysl#{roc}_#{se}.pik"
    headers['Content-Type'] = "text/plain; charset=UTF-8";
    render layout: nil
  end

  def _results_updated?(annual, round)
    solvers = get_sorted_solvers(annual: annual).to_a
    res_min = Sosna::Result.where(annual:annual, round: round, solver_id: solvers.map{ |s| s.id } ).minimum(:updated_at)
    sol_max = Sosna::Solution.joins(:problem).where('sosna_problems.annual' => annual, 'sosna_problems.round' =>  round).maximum(:updated_at)
    pen_max = Sosna::Penalisation.where(annual:annual, round: round).maximum(:updated_at)
    rrr = Sosna::Result.where(annual: annual, round: round, updated_at: res_min).first
    log("res_min=#{res_min} sol_max=#{sol_max} pen_max=#{pen_max} annual=#{annual} round=#{round} rrr=#{rrr.inspect}")
    return false if res_min < sol_max
    return false if res_min < pen_max
    return true
  end

  ##
  #  GET  /sosna/solutions/vyslwiki(/:roc(/:se(/:ul)))
  #
  # export vysledkovky `.wiki`.
  #
  # *Params*
  # roc, se, ul:: ročník, série, úloha, pokud není vezme se aktuální
  #
  # *Provide*
  # @solvers, @problems, @solutions_by_solver, @penalisations_by_solver, @results_by_solver:: jako `index`
  #
  # *Template* app/views/sosna/solution/vysl_wiki.erb
  def vysl_wiki
    roc, se, ul = _params_roc_se_ul
    if ! _results_updated?(roc, se)
      add_alert 'Výsledky nejsou aktuální, použij "Vygeneruj výsledky"'
      return redirect_to sosna_solutions_org_path(roc, se)
    end
    _prepare_solvers_problems_solutions(want_test: false, want_bonus: false)
    _sort_solvers_by_rank
    headers['Content-Disposition'] = "inline; filename=vysl#{roc}_#{se}.wiki"
    headers['Content-Type'] = "text/plain; charset=UTF-8";
    render layout: nil
  end

  ##
  #  GET  /sosna/solutions/:roc/:se/edit
  #  GET  /sosna/solutions/:roc/:se/:ul/edit
  #
  # *Params*
  # roc, se, ul:: ročník, série, úloha, pokud není vezme se aktuální
  # paper:: chci editovat papery
  # penalisation:: chci editovat penalizaci
  #
  # *Provide*
  # @solvers, @problems, @solutions_by_solver, @penalisations_by_solver, @results_by_solver:: jako `index`
  # @want_edit, @want_edit_paper, @want_edit_penalisation:: co se chce editovat
  #
  # *Render* index
  def edit
    _prepare_solvers_problems_solutions(want_test: true)
    @want_edit_paper = @want_edit = @want_edit_penalisation = false
    if !params[:paper].nil?
      @want_edit_paper = true
    elsif !params[:penalisation].nil?
      @want_edit_penalisation = true
    else
      @want_edit = true
    end
    render :index
  end

  ##
  #  POST '/sosna/solutions/update_papers
  #
  # *Params*
  # roc, se, ul:: jako všude
  # paper[]:: hash solution.id => 1 / nil
  #
  # *Redirect* edit
  def update_papers
    roc, se, ul = params[:roc], params[:se], params[:ul]
    paper = params[:paper] || {}

    Sosna::Solution.includes(:problem).where(:sosna_problems => {:annual => roc, :round => se}).each do |sol|
      has_paper_mail = paper.has_key?  sol.id.to_s
      if sol.has_paper_mail != has_paper_mail
        sol.has_paper_mail = has_paper_mail
        sol.save
      end
    end
    redirect_to action: :edit, roc: roc, se: se, ul: ul, paper: 'yes'
  end

  ##
  #  POST /sosna/solutions/update_penalisations
  #
  # *Params*
  # roc, se, ul:: jako všude
  # penalisation_score[]:: hash penalisation.id => score  / nil
  # penalisation_title[]:: hash penalisation.id => title (kometář) / nil
  #
  # *Redirect* edit
  #
  def update_penalisations
    roc, se, ul = params[:roc], params[:se], params[:ul]
    scores = params[:penalisation_score] || {}
    titles = params[:penalisation_title] || {}
    Sosna::Penalisation.find(scores.keys).each do |pen|
      id = pen.id.to_s
      sc = scores[id]
      sc = nil if sc == '-'
      tit = titles[id]
      tit = nil if tit == ''
      if pen.score != sc || pen.title != tit
        pen.score = sc
        pen.title = tit
        pen.save
      end
    end
    redirect_to action: :edit, roc: roc, se: se, ul: ul, penalisation: 'yes'
  end

  ##
  #  POST /sosna/solutions/update_scores
  #
  # *Params*
  # roc, se, ul:: jako všude
  # score[]:: hash penalisation.id => score  / nil
  # penalisation_title[]:: hash solution.id => počet bodů / nil
  #
  # *Redirect* edit
  def update_scores
    roc, se, ul = params[:roc], params[:se], params[:ul]
    scores = params[:score] || {}
    solutions = Sosna::Solution.find(scores.keys)

    solutions.each do |sol|

      id = sol.id.to_s

      score = begin Integer scores[id] ; rescue ; nil ;  end

      if sol.score != score
        sol.score = score
        sol.save
      end
    end

    redirect_to action: :edit, roc: roc, se: se, ul: ul
  end

  ##
  #  GET  '/sosna/solution/confirm_files'            => 'sosna/solution#get_confirm_files',    :as => :sosna_solutions_get_confirm_files
  def get_confirm_files
    zip_file = Tempfile.new(['confirmations', '.zip'], UPLOAD_DIR)
    zip_file_name = zip_file.path
    zip_file.unlink
    annual = params[:annual] || @config[:annual]
    solvers = Sosna::Solver.where(annual: annual)

    # Zip::File.open potrebuej aby zip_file_naem (neexistovalo
    # jinak si zacne myslet, ze zip chci otevrit a ne prepsat
    # naopak Tempfile nedokaze jen vymyslet jmeno a neotevirat
    Zip::File.open(zip_file_name, Zip::File::CREATE) do |zipfile|
      solvers.each do |solver|
        filename = _confirm_file_path solver
        next if filename.nil? || ! File.exists?(filename)
        zipfile.add(translit("navratky/confirm-file-#{solver.last_name}-#{solver.name}-#{solver.id}.pdf"),  filename)
      end
    end
    send_file zip_file_name, :filename => 'navratky.zip', :type => "application/zip"
  end


  ##
  #  POST  /sosna/solutions/upload_confirm
  #
  # Upload souboru s návratkou.
  #
  # *Params*
  # roc, se, ul:: jako všude
  # confirm_file::
  #
  # *Redirect* user_index
  def upload_confirm_file

    confirm_file = params[:confirm_file]

    roc = params[:roc]
    se =  params[:se]
    solver = Sosna::Solver.where(annual: @annual, user_id: current_user.id).first

    if solver.nil?
        add_alert 'Bad user and solver'
    elsif confirm_file.nil?
      File.delete _confirm_file_path(solver)
      add_alert 'Návratka byla smazána'
    elsif confirm_file.original_filename !~ /\.pdf$/
      add_alert 'Pozor: pouze soubory ve formátu .pdf'
    else
      File.open(_confirm_file_path(solver), 'wb') {  |f| f.write confirm_file.read }
      add_success 'Návratka nahrána'
    end
    redirect_to sosna_solutions_user_url(roc, se, solver.id)
  end


  ##
  #  GET  /sosna/solutions/confirm_file
  #
  # Dwondload Upload potvrzením údajů.
  #
  def get_confirm_file
    solver = Sosna::Solver.where(annual: @annual, user_id: current_user.id).first
    if ! solver.nil?
       send_file _confirm_file_path(solver) , :filename => 'navratka.pdf', :type => 'application/pdf'
    end
  end


  ##
  #  GET /sosna/solution/:id/down_rev
  #
  # Download opravy. Pokud aktuální uživatel neni `org`, může jen pokud svoje řešení.
  #
  # *Params*
  # id:: id Sosna::Solution
  def download_rev
    solution = Sosna::Solution.find id = params[:id]
    if ! solution
      add_alert 'Chyba: soubor neexistuje'
      return redirect_to :action =>  :user_index
    end

    if solution.owner? current_user
      # owner: check if it allowed to download
      round = solution.problem.round
      annual = solution.problem.annual
      sol_in_this_round_allowed   = round <  @config[:round].to_i
      sol_in_this_round_allowed ||= round == @config[:round].to_i && @config[:show_revisions] == 'yes'
      sol_in_this_round_allowed ||= annual < @config[:annual].to_i
      if ! sol_in_this_round_allowed
        add_alert "Chyba: soubor ještě neexistuje"
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

  ##
  #  GET /sosna/solution/:id/down(/:ori)
  #
  # Download řešení. Pokud aktuální uživatel neni `org`, může jen pokud svoje řešení.
  #
  # *Params*
  # id:: id Sosna::Solution
  # ori::  ??? nepoužívá se
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

  ##
  #  GET /sosna/solutions/user(/:roc(/:se(/:id)))+
  #
  # *Params*
  # roc, se, ul:: ročník, série, úloha, pokud není vezme se aktuální
  # rev:: pokud se chce oprava.
  #
  # *Provides*
  # @annual:: ročník
  # @solver:: `Sosna::Solver`
  # @is_current:: `true` když se je aktualní ročník a serie
  # @solver_is_current_user:: *true* když, se dívá uživatel dívá na sebe
  # @problems::  pole `Sosna::Problem` úloh dané série
  # @solutions_by_solver::  hash solver.id => { problem.problem_no => solution }
  def downall
    want_rev = ! params[:rev].nil?
    problems = _problems_from_roc_se_ul
    solutions = _solutions_from_problems problems

    zip_file = Tempfile.new(['solution', '.zip'], UPLOAD_DIR)
    zip_file_name = zip_file.path
    zip_file.unlink

    # Zip::File.open potrebuej aby zip_file_naem (neexistovalo
    # jinak si zacne myslet, ze zip chci otevrit a ne prepsat
    # naopak Tempfile nedokaze jen vymyslet jmeno a neotevirat
    Zip::File.open(zip_file_name, Zip::File::CREATE) do |zipfile|
      solutions.each do |solution|
        if want_rev
          filename = solution.filename_corr
          filename_disp = solution.get_filename_rev
        else
          filename = solution.filename
          filename_disp = solution.get_filename_ori
        end
        next if filename.nil?
        zipfile.add('reseni/' + File.basename(filename_disp),  UPLOAD_DIR + filename)
      end
    end
    log("zip size:#{File::size?(zip_file_name)}")
    send_file zip_file_name, :filename => 'reseni.zip', :type => "application/zip", :x_sendfile => true
    #File.delete zip_file_name
  end

  ##
  #  POST /sosna/solution/upload_rev
  #
  # Upload jednotlive opravy
  #
  # *Params*
  # roc, se, ul:: ročník, série, úloha, pokud není vezme se aktuální
  # file_rev:: upload
  #
  # *Redirect* user_index
  def upload_rev
    rfile = params[:file_rev]
    roc = params[:roc]
    se =  params[:se]
    ul =  params[:ul]


    # reseni-roc29-se01-ul2-rel001-ori-vitas-vitas.pdf
    # reseni-roc29-se01-ul2-rel001-rev-vitas-vitas.pdf
    if rfile.nil?
      add_alert "no uploaded file (param file_rev)"
    else
      cfile_name = rfile.original_filename

      if cfile_name =~ /\.pdf$/
         path =  _upload_rev_one(roc, se, ul,  cfile_name)
         if path
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
    end
    redirect_to :action =>  :index, :roc => roc, :se => se, :ul => ul
  end

  ##
  #  GET  /sosna/solutions/user(/:roc(/:se(/:id)))
  #
  # *Params*
  # roc, se, ul:: ročník, série, úloha, pokud není vezme se aktuální
  # id::  id `Sosna::Solver`, pokud není pokusí se najít letošního řešitele,
  #       přihlášeného uživatele; je nutné mít `:org`
  #
  # *Provides*
  #
  # @annual:: rok
  # @solver:: +Sosna::Solver+
  # @is_current:: `true* když se je aktualní ročník a serie
  # @solver_is_current_user:: `true` když, se dívá uživatel dívá na sebe
  # @problems::  pole `Sosna::Problem` úloh dané série
  # @solutions_by_solver::  hash solver.id => { problem.problem_no => solution }
  def user_index

    @annual = params[:roc] || @config[:annual]
    #@annual = @config[:annual]
    solver_id = params[:id]
    @round  = params[:se] || 1
    if @round.nil?
      @round = if @config[:round].to_i < Sosna::Problem::BONUS_ROUND_NUM
                   # not bonus
                   @config[:round]
               else
                   _max_round_non_bonus(@annual)
               end
    end

    @breadcrumb = [[breadcrumb_annual_links(:user_index)], _rounds_roc_links(@annual, @round, :user_index) ]

    @is_current = (@annual == @config[:annual] && @round ==  @config[:round])

    raise 'not logged' if current_user.nil?

    current_solver = Sosna::Solver.where(:user_id => current_user.id, :annual => @annual).take

    if solver_id && (current_solver.nil? || current_solver.id != solver_id )
      authorize! :user_index_org, Sosna::Solution
      @solver = Sosna::Solver.find(solver_id)
    else
      @solver = current_solver
      @solver_is_current_user = true
    end

    if ! @solver && current_user.org?
      add_alert "Pozor: zatím nejsi letošním řešitelem, a navíc jsi org!"
      return redirect_to wiki_piki_path('/')
    end
    if ! @solver
      add_alert "Pozor: zatím nejsi letošním řešitelem, nejprve vyplň přihlašku!"
      return redirect_to :controller => :solver , :action => :new
    end

    if ! @solver && @annual.to_i < @config[:annual].to_i
       add_alert_now "V ročníku #{@annual} jsi nebyl řešitelem!"
       return render :empty
    end

    if @config[:confirmation_round] == @round
      @show_confirmation_upload = true
      @confirmation_exists = File.exists? _confirm_file_path @solver
    end

    @problems  = Sosna::Problem.where(:annual=> @annual, :round=> @round)
    @solutions_by_solver = _solutions_by_solver [@solver], @problems

    if @solver.confirm_state == 'next' && !current_user.admin?
      add_alert "Pozor: musíš nejprve potvrdit návratku."
      return redirect_to :sosna_solver_user_solver_confirm
      #@alert_link = {:text => "Prosím potvrď", :url => url_for(:sosna_solver_user_solver_confirm),  :url_text => "návratku"}
    end
  end

  ##
  #  GET  /sosna/solutions/bonus
  #
  # Upload bonusové serie je trošku speciální, ale v postatě se využívá `user_index`
  #
  # *Params*
  # se:: série
  #
  # *Provides*
  # @hide_non_bonus_in_breadcrumb:: true
  #
  # *Render* user_index
  def user_bonus
    params[:se] = Sosna::Problem::BONUS_ROUND_NUM.to_s
    @hide_non_bonus_in_breadcrumb = true
    user_index
    render :user_index
  end

  ##
  #  PATCH /sosna/solution/upload
  #
  # Upload řešení, (by uživatel nebo org)
  #
  # *Params*
  # sosna_solution.solution_file:: upload
  # sosna_solution.id:: id `Sosna::Solution`
  #
  # *Redirect* user_index
  def upload
    solution_file = params[:sosna_solution][:solution_file]
    solution_id  = params[:sosna_solution][:id]

    # find solution
    solution = Sosna::Solution.find(solution_id) or raise RuntimeError, "bad solution id: #{solution_id}"
    if ! solution
      add_alert "Chyba: solution #{solution_id} neexistuje"
      return redirect_to :action =>  :user_index
    end

    is_owner = solution.owner?(current_user)
    authorize! :upload_org, Sosna::Solution if ! is_owner

    if !solution
      add_alert "Špatné číslo řešení"
      return redirect_to sosna_solutions_user_url(roc, se, solver.id)
    end
    problem, solver  = solution.problem, solution.solver
    se = problem.round
    roc = problem.annual

    solver_id_or_nil = is_owner ? nil : solver.id

    deadline = deadline_time(@config, problem.round)
    if problem.annual.to_s != @config[:annual] || !deadline || deadline  < Time.now
      # po deadline muze nahravat pouze pouze admin
      if ! current_user.admin?
        pp solution.problem.annual != @config[:annual]
        pp @config[:annual]
        pp solution.problem.annual
        pp deadline_time(@config, solution.problem.round)
        add_alert "Řešení není možné odevdat (pozdní termín)"
        return redirect_to sosna_solutions_user_url(roc, se, solver_id_or_nil)
      end
    end


    if solution_file.nil?
      solution.filename = nil
      solution.filename_orig = nil
      solution.save
      add_success "Soubor smazán"
      return redirect_to sosna_solutions_user_url(roc, se) if is_owner
      return redirect_to sosna_solutions_user_url(roc, se, solver.id)
    end

    if solution_file.original_filename !~ /\.pdf$/i
      add_alert 'Pozor: pouze soubory ve formátu .pdf'
      return redirect_to sosna_solutions_user_url(roc, se, solver_id_or_nil)
    end

    max_size =  Rails.configuration.sosna_user_solution_max_size || (20 * 1024 * 1024)
    if solution_file.size > max_size
      add_alert "Soubor je příliš velký (větší než #{number_to_human_size max_size})."
      return redirect_to sosna_solutions_user_url(roc, se, solver_id_or_nil)
    end

    # save file
    filename = solution.get_filename_ori
    File.open(UPLOAD_DIR + filename, 'wb') {  |f| f.write(solution_file.read) }

    _sign_pdf(solution, UPLOAD_DIR + filename)

    # update solution
    solution.filename = filename
    solution.filename_orig = solution_file.original_filename
    solution.save
    add_success 'Soubor úspěšně nahrán'

    redirect_to sosna_solutions_user_url(roc, se, solver_id_or_nil)
  end

  ##
  #  POST  /sosna/solution/:id/resing
  #
  # Způsobí znova vepsání hlaviček do `.pdf`. Může jen `admin`
  #
  # *Params*
  # id:: id `Sosna::Solution`
  #
  # *Redirect* user_index
  def resign
    solution_id  = params[:id]
    solution = Sosna::Solution.find(solution_id) or raise RuntimeError, "bad solution id: #{solution_id}"
    if ! solution
      add_alert "Chyba: solution #{solution_id} neexistuje"
      return redirect_to sosna_solutions_user_url(roc, se)
    end

    _sign_pdf(solution, UPLOAD_DIR + solution.get_filename_ori, false)
    add_success("file resigned")
    problem = solution.problem
    se = problem.round
    roc = problem.annual
    redirect_to sosna_solutions_user_url(roc, se, solution.solver.id)
  end

  ##
  #  POST  /sosna/solution/:id/nosign
  #
  # Návrat k originálu, bez vepsané hlavičky hlaviček, v některých (nějaké generátory pdf) případech totiž vepisování způsobí, že celé pdf je poškozené a nejde přečíst.
  #
  # *Params*
  # id:: id `Sosna::Solution`
  #
  # *Redirect* user_index
  def nosign
    solution_id  = params[:id]
    solution = Sosna::Solution.find(solution_id) or raise RuntimeError, "bad solution id: #{solution_id}"
    if ! solution
      add_alert "Chyba: solution #{solution_id} neexistuje"
      return redirect_to sosna_solutions_user_url(roc, se)
    end

    dest = UPLOAD_DIR + solution.get_filename_ori
    template =  dest + '.tmpl'
    FileUtils::cp  template, dest
    add_success("file unsigned")
    problem = solution.problem
    se = problem.round
    roc = problem.annual
    redirect_to sosna_solutions_user_url(roc, se, solution.solver.id)
  end


  ##
  #  POST /sosna/solution/update_results
  #
  # *Pocitani výsledků*
  #
  # pocet bodu se pocita ze seti nejlepsich prikladu (ze sedmi)
  # pripocte se pocet bodu za minulou serii (pokdu byla)
  # a spocita se poradi (a pokud ma stejne bodu tak interval porad)
  # a spocita se poradi v rocniku (a pokud ma stejne bodu tak interval poradi)
  #
  # *Params*
  # roc, se, ul:: ročník, série, úloha, pokud není vezme se aktuální
  #
  # *Redirect* index
  def update_results
    roc, se, ul = _params_roc_se_ul

    # resitele
    solvers = get_sorted_solvers(annual: roc).to_a

    # vysledky (budou zmeneny)
    results_by_solver = _get_results_by_solver(solvers, roc, se)

    # vysledky z minule seri
    results_last = _get_results_by_solver(solvers, roc, se.to_i - 1, false)

    # priklady v teto serii
    problems = Sosna::Problem.where(:annual => roc, :round => se).where(Sosna::Problem.arel_table[:problem_no].lt(Sosna::Problem::BONUS_PROBLEM_NUM))

    # penalizace za tuto serii
    pens = Sosna::Penalisation.where(:annual => roc, :round => se)

    # poblemy podle id
    problems_by_id = {}
    problems.each{|p| problems_by_id[p.id] = p}

    # resitele podle id
    pens_by_solver_id = {}
    pens.each{|p| pens_by_solver_id[p.solver_id] = p.score }

    # pocty bodu za dane ulohy
    scores = {}
    Sosna::Solution.where(:problem_id => problems.map{|p|p.id}).each do  |sol|
      scores[sol.solver_id] ||= {}
      scores[sol.solver_id][problems_by_id[sol.problem_id].problem_no] = sol.score || 0
    end

    # spocitej body kazdemu resitely
    solver_scores = {}
    solvers.each do |solver|
      score, comment = _compute_round_score( scores[solver.id] || [])
      res = results_by_solver[solver.id]
      score -=  pens_by_solver_id[solver.id] || 0
      # kdyby penalizace mela byt vetsi nez pocet bodu, tak ji nepocitej
      score = [score, 0].max
      res.comment = comment
      res.round_score = score
      lres = results_last[solver.id]
      res.score = (score||0) + ( lres.nil? ? 0 : (lres.score||0) )
    end

    # setridime od nejvice bodu
    solvers.sort_by! { |solver| results_by_solver[solver.id].score  }.reverse!

    # priradime poradi (rank)
    rank = 0

    # od prvnich mist
    i = 0

    # poradi v rocniku (klic je round_num, tedy cislo rocniku)
    grade_rank = {}

    while  i < solvers.size do
      cur_score = results_by_solver[solvers[i].id].score
      first_i = i

      # dojed na konec bloku lidi se stejnymi body
      while true
        i += 1
        break if i >= solvers.size
        break if results_by_solver[solvers[i].id].score != cur_score
      end

      # pocet lidi z kazdeho rocniku  v tomto bloku (klicem je cislo rocniku)
      grade_count = {}

      # nastav jim poradi, a zaroven spocitej kolik je v tomto bloku lidi z jake tridy
      (first_i .. i - 1).each do |j|
        # nastav jim to
        solver = solvers[j]
        res = results_by_solver[solver.id]
        res.rank = first_i + 1
        res.rank_to = (i - 1) + 1
        grade_count[solver.grade_num] = (grade_count[solver.grade_num] || 0) + 1
      end

      # resitelum z tohoto bloku nastav poradi v rocniku
      (first_i .. i - 1).each do |j|
        solver = solvers[j]
        grade = solver.grade_num
        res = results_by_solver[solver.id]
        cr = grade_rank[grade] || 1
        ct = cr + grade_count[grade] - 1
        res.class_rank = cr
        res.class_rank_to = ct
      end

      # aktualizuj pocet poradi lidi v rocniku, po tomto bloku lidi
      grade_count.each { |grade, count| grade_rank[grade] = ( grade_rank[grade] || 1 ) + count }
    end

    # a ulozit vysledky
    results_by_solver.each do |id,res|
      res.save
      res.touch
    end

    # presmerovat na zobrazeni tabukly
    add_success "výsledky pro rocnik #{roc} serie #{se} byly přegenrovány"
    redirect_to :action =>  :index , :roc => roc, :se => se
  end

  private

  # scores hash of integers (key are problem_no, values are score)
  #  { '1' => 5, '2'=>'1',  '3'=>1,  '4' => 3, '5' => 1, '6' => 1, '7' => 0 }
  def _compute_round_score(scores)
    # sest nejlepsich prikladu [ ['1' => 5], [ '4' => 3], ['2' => 1], ...
    # [ 7 => 0] omnited
    top6 = scores.to_a.sort {|a,b| b[1] <=> a[1]} [ 0 .. 5 ]

    # ktere priklady to byly
    comment = top6.map {|x| x[0]}.join(',')

    # soucet bodu za nejlepsi priklady
    sum = top6.inject(0) { |sum,x| sum + x[1] }
    return sum, comment
  end

  def _get_results(solvers, roc, se)
    Sosna::Result.where(:solver_id => solvers.map{ |s| s.id },
                        :annual => roc,
                        :round => se).load

  end

  # r: { solver_id => [ result1,  result2, ... ], ... }

  def _get_results_by_solver(solvers, roc, se, want_create = true)
    _results = _get_results(solvers, roc, se)
    results_by_solver = {}
    _results.each { |r| results_by_solver[r.solver_id] = r }
    solvers.each do |solver|
      if results_by_solver[solver.id].nil? && want_create
          begin
            results_by_solver[solver.id] = Sosna::Result.create({ :solver_id => solver.id,
                                                                            :annual => @annual,
                                                                            :round => @round, })
          rescue Exception => e
            log(" results_by_solver :Solution.create -> #{e.to_s}")
          end
      end
    end
    #return results_by_solver, _results
    return results_by_solver
  end

  def _penalisations_by_solver(solvers)
    penalisations = Sosna::Penalisation.where(:solver_id => solvers.map{ |s| s.id },
                                              :annual => @annual,
                                              :round => @round).load
    penalisations_by_solver = {}
    penalisations.each { |p| penalisations_by_solver[p.solver_id] = p }
    solvers.each do |solver|
      if penalisations_by_solver[solver.id].nil?
          begin
            penalisations_by_solver[solver.id] = Sosna::Penalisation.create({
                                                                        :solver_id => solver.id,
                                                                        :annual => @annual,
                                                                        :round => @round, })
          rescue Exception => e
            log(" penalisations_by_solver :Solution.create -> #{e.to_s}")
          end
      end
    end
    penalisations_by_solver
  end

  # { solver.id => { problem.problem_no => solution }}
  def _solutions_by_solver(solvers, problems)
    solutions = Sosna::Solution.where( :solver_id  => solvers.map{ |s| s.id },
                                       :problem_id => problems.map { |p| p.id },
                                    )
    solutions_by_solver = []
    problems_by_id = {}
    problems.each { |p| problems_by_id[p.id] = p }

    # solution_by_solver[solver_id][problem_no] => solution
    solutions.each do |sol|
      solutions_by_solver[sol.solver_id] ||= []
      problem_no = problems_by_id[sol.problem_id].problem_no
      solutions_by_solver[sol.solver_id][problem_no] =  sol
    end

    # fill missing solutions
    solvers.each do |solver|
      solutions_by_solver[solver.id] ||= []
      problems.each do |pr|
        if solutions_by_solver[solver.id][pr.problem_no].nil?
          begin
            sol = Sosna::Solution.create({ :solver_id => solver.id, :problem_id => pr.id, })
          rescue Exception => e
            log(" solutions_from_roc_se_ul_by_solver:Solution.create -> #{e.to_s}")
          end
          solutions_by_solver[solver.id][pr.problem_no] = sol
        end
      end
    end
    solutions_by_solver
  end

  def _load_index
    @want_edit = false
    @want_edit_paper = false
    @want_edit_penalisation = false
    path = [ breadcrumb_annual_links(:index) ]

    dir = nil
    @action_more = false
    if @problem_no
      # in level problem
      path.push(_round_link(@annual, @round))
      path.push(_problem_link(@annual, @round, @problem_no))
      path[-1][:sub] = _problems_roc_se(@annual, @round)
    elsif @round
      # in level round
      path.push(_round_link(@annual, @round))
      path[-1][:sub] = _rounds_roc_links(@annual)
      @action_buttons = []

      dir = _problems_roc_se(@annual, @round)
    else
      # in level annual
      @annuals = _annuals
      dir = _rounds_roc_links(@annual)
    end
    @breadcrumb = dir.nil? ? [path] : [ path, dir ]
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

    fname.force_encoding('UTF-8')
    if fname !~ /^(?:.*\/)?reseni-roc(\d+)-se(\d+)-ul(\d+)-rel(\d+)-(ori|rev)-.*.pdf$/
      _add_msg(fname, "jmeno souboru neni ve spravnem formatu, ocekavany format: DIR/reseni-rocNN-seN-ulN-relN-(ori|rev)-.*.pdf")
      return nil
    end
    oroc, ose, oul, relid = $1.to_i, $2.to_i, $3.to_i, $4.to_i

    if oroc.to_s != roc || ose.to_s != se || oul.to_s != ul
       _add_msg(fname, "reseni neni ke spravnemu rocniku, serii, uloze")
      return nil
    end

    solver = Sosna::Solver.find_by_id(relid)
    if !solver
       _add_msg(fname, "neexistuje takovy resitel #{relid}")
       return nil
    end

    problem = Sosna::Problem.where(:annual => roc, :round => se, :problem_no => ul).take
    solution = Sosna::Solution.where( :problem_id => problem.id, :solver_id => solver.id).take

    #filename_corr = _solution_filename(problem, solver, true)
    filename_rev = solution.get_filename_rev
    solution.filename_corr = filename_rev
    solution.filename_corr_display =  _filename_rev_display(solution.filename_orig||filename_rev)
    solution.save

    print "solution id: #{solution.id}, #{solution.filename_corr}\n"
    _add_msg(fname, "ok", true)
    return filename_rev

  end

  def _filename_rev_display(orig)
      orig.sub(/(\.[^\.]+)$/, '-opraveno\1')
  end


  def _sign_pdf(solution, dest, overwrite = true)
      problem = solution.problem
      solver = solution.solver
      name = "#{solver.last_name} #{solver.name}"
      ulfull = "roč#{problem.annual} se#{problem.round} ul#{problem.problem_no}"

      template = dest + '.tmpl'
      FileUtils::cp  dest, template if overwrite

      begin
        pdf = CombinePDF.load(template)

        # FIXME
        # combine_pdf zatím neumí utf, takže musíme hlavičku odháčkovat
        # také neumí změnit font.

        fmt_left = translit "#{ulfull} #{name}"
        fmt_right = translit "str%s/#{pdf.pages.count}"
        pdf.number_pages(:number_format => fmt_left, :location => [:top_left, :bottom_left], :margin_from_height => 30)
        pdf.number_pages(:number_format => fmt_right, :location => [:top_right, :bottom_right], :margin_from_height => 30)

        pdf.save dest
      rescue Exception => e
        log("Hlavicka fail: #{e.to_s}")
        FileUtils::cp template, dest
      end
  end

  def _params_roc_se_ul
    roc, se, ul = params[:roc],  params[:se], params[:ul]
    load_config

    if roc.nil? && se.nil?
        roc  = @annual
        se  = @round
    end
    se ||= 1

    @annual = roc
    @round = se
    @problem_no = ul
    log("roc:#{roc} se:#{se} ul:#{ul}\n")

    return roc, se, ul
  end

  def _sort_solvers_by_grade
    @solvers.sort! do  |a,b|
        agr = a.grade_num || '1'
        bgr = b.grade_num || '1'
        if agr != bgr
          agr <=> bgr
        elsif a.last_name != b.last_name
          strcollf(a.last_name, b.last_name)
        elsif a.name != b.name
          strcollf(a.name, b.name)
        else
          a.id <=> b.id
        end
    end
  end

  def _sort_solvers_by_rank
    r_by_s = @results_by_solver
    @solvers.sort! do  |a,b|
        ares= r_by_s[a.id]
        bres= r_by_s[b.id]
        return 0 if ares.rank.nil? && bres.rank.nil?
        return -1 if ares.rank.nil?
        return 1 if bres.rank.nil?
        if ares.rank != bres.rank
          ares.rank <=> bres.rank
        else
          agr = a.grade_num || '1'
          bgr = b.grade_num || '1'
          if agr != bgr
            agr <=> bgr
          elsif a.last_name != b.last_name
            strcollf(a.last_name||'', b.last_name||'')
          elsif a.name != b.name
            strcollf(a.name||'', b.name||'')
          else
            a.id <=> b.id
          end
        end
     end
  end

  def _prepare_solvers_problems_solutions(want_test: true, want_bonus: true)
    _params_roc_se_ul
    where = { annual: @annual}
    where.merge!({is_test_solver: false }) if ! want_test
    @solvers = get_sorted_solvers(where)
    @problems = _problems_from_roc_se_ul
    @problems = @problems.select {|pr| !pr.bonus?} if ! want_bonus
    @solutions_by_solver = _solutions_by_solver @solvers, @problems
    @penalisations_by_solver = _penalisations_by_solver @solvers
    @results_by_solver = _get_results_by_solver(@solvers, @annual, @round)
    if !params[:sous].nil?
      @want_sous = true
      @solvers = @solvers.select { |solver| (!solver.is_test_solver) && ((@results_by_solver[solver.id].class_rank||100) < 10) }
    end
  end

  def _prepare_solvers_by_ranks
  end

  def _problems_from_roc_se_ul()
    roc, se, ul = _params_roc_se_ul
    if ul
      return Sosna::Problem.where(:annual => roc, :round => se, :problem_no => ul)
    else
      return Sosna::Problem.where(:annual => roc, :round => se).order(:problem_no)
    end
  end

  def _solutions_from_problems(problems)
      Sosna::Solution.where(:problem_id => problems.map{|p| p.id}).load
  end


  # r: links to problems
  def _problems_roc_se(roc, se, action = :index)
      return Sosna::Problem.where({:annual => roc, :round => se})
                         .load
                         .map do |ul|
                              _problem_link(@annual, @round, ul.problem_no, action)
                         end

  end

  # r: list of "links" to
  # r: [ { name: "", url:""}, ... ]
  def _rounds_roc_links(roc, se = nil, action = :index)
    rounds = []
    serie_is_bonus = is_bonus_round(se)
    Sosna::Problem.select('round')
                       .where({annual: roc})
                       .group('round')
                       .order('round')
                       .load
                       .each do |pr|
                          round_str = pr.round.to_s
                          is_bonus = is_bonus_round(round_str)
                          next if @hide_non_bonus_in_breadcrumb && !is_bonus
                          rounds.push _round_link(roc, pr.round, round_str == se, action)
                       end
    rounds
  end

  # r: list of "links" to
  # r: [ { name: "", url:""}, ... ]
  def _rounds_roc(roc)
    rounds = []
    Sosna::Problem.select('round')
                       .where({annual: roc})
                       .group('round')
                       .order('round')
                       .load
                       .each do |problem|
                          rounds.push problem.round
                       end
    return rounds
  end

  def _problem_link(annual, round, problem_no, action = :index)
      {name: "Úloha #{problem_no}", url: {action: action, roc: annual, se: round, ul: problem_no}}
  end


  def _round_link(annual, round, active= false, action = :index)
     if is_bonus_round(round)
       {name: "Bonusová série", active: active, url: {action: action, roc: annual, se: round}}
     else
       {name: "Série #{round}", active: active, url: {action: action, roc: annual, se: round}}
     end
  end

  def _annuals
    annual = {}
    Sosna::Problem.select('annual')
                       .group('annual')
                       .order('annual desc')
                       .each do |a|
                            annual[a.annual] = _rounds_roc_links(a.annual)
                       end
    return annual
  end
  def _max_round_non_bonus(annual)
     max = Sosna::Problem
                       .where({annual: annual})
                       .where(Sosna::Problem.arel_table[:round].lt(Sosna::Problem::BONUS_ROUND_NUM))
                       .maximum('round')
     max.to_s
  end

  def _confirm_file_path(solver)
         UPLOAD_DIR + "confirm-file-#{solver.id}.pdf"
  end


end
