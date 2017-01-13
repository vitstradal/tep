# encoding: utf-8
require 'ffi-locale'
class Sosna::SolverController < SosnaController

  include ApplicationHelper

  def index
    load_config
    @annual = params[:roc] || @annual
    @solvers = get_sorted_solvers(annual: @annual)
    respond_to do |format|
      format.html do
         @solver_names =  {}
         @solvers.each do |s|
           @solver_names[s.full_name] = @solver_names[s.full_name].to_i + 1
         end
      end
      format.pik do
         headers['Content-Disposition'] = "attachment; filename=lidi-roc#{@annual}.pik"
         headers['Content-Type'] = "text/plain; charset=UTF-8";
      end
    end
    @breadcrumb = [[breadcrumb_annual_links(:index)]];
  end

  def tep_emails
    @annual = params[:roc] || @annual
    @solvers = Sosna::Solver.where solution_form: 'tep', annual: @annual, is_test_solver: false
  end


  def dup
    solver_id = params[:id]
    annual = params[:roc] || @annual

    solver = Sosna::Solver.find(solver_id)
    if solver.nil?
      add_alert "no such solver #{solver_id}"
      redirect_to sosna_solver_show(solver_id);
    end
    if solver.annual == annual
      add_alert "stejny rocnik pro duplikaci"
      redirect_to sosna_solver_show(solver_id);
    end

    solver_dup = solver.dup;
    solver_dup.annual = annual
    solver_dup.save
    redirect_to sosna_solver_url(solver_dup.id);
  end

  def labels
    @annual = params[:roc] || @annual
    @ids = (params[:ids]  || '').gsub(/;.*$/,'').split(/[,\n\s]+/).map { |x| x.to_i }
    log("ids:" +  @ids.to_s);

    respond_to do |format|
      format.html
      format.pdf do
         @opt = {}
         @envelope= params[:envelope]
         params[:opt].split(/\s*;\s*|\s+/).each do |o|
           @opt[$1.to_sym] = $2 if o =~ /^\s*(\w+)\s*:(\S*)/
         end

         @prawnto_options = { :prawn => {:page_size => @opt[:p] || 'C5', :page_layout => :landscape, }} if @envelope;

         @dbg = params[:dbg]
         where = nil
         @solvers = []
         if @ids.size > 0
           @solvers = get_sorted_solvers({ id: @ids})
         elsif params[:paper_tep_conflict]
           @round = params[:se] || @round
           @solvers = get_sorted_conflict_solvers(@annual, @round);
           log("solver count=#{@solvers.size}")
         else
           where = {annual: @annual, is_test_solver: false}
           where.merge!({ where_to_send: ['home', 'school'] }) if params[:obalkovani]
           where.merge!({ confirm_state: 'conf'}) if params[:confirmed_only]
           @solvers = get_sorted_solvers(where);
         end
         @schools = []
         @schools = Sosna::School.where(want_paper: true) if params[:skoly]
         render :formats => [:pdf]
       end
    end
  end

  def confirm_none_to_next
    solvers = Sosna::Solver.where(:annual =>  @annual, :confirm_state => 'none').all
    solvers.each do |solver|
      solver.confirm_state = 'next'
      solver.save
    end
    add_success "Celkem #{solvers.size} uživatelů bylo převedeno do návratkového (confirmed_state ='next')"
    redirect_to :sosna_solvers
  end

#  def delete_zero_solvers
#    add_alert "not yet implemented"
#    redirect_to :sosna_solvers
#  end

  def delete
     id = params[:id]
     u = Sosna::Solver.find(id)
     if u
       u.destroy
       add_success 'řešitel smazán'
     else
       add_alert 'řešitel neexistuje'
     end
     redirect_to action: :index
  end

  def _load_schools
    @schools = Sosna::School.all.load
    @schools_sorted = @schools.sort_by { |s|
      # kažedé číslo v názvu města dopň na deset cifer
      # Praha 1  => Praha 0001
      # Praha 10 => Praha 0010
      # (toto bude klíč k třízení, nebude se zobrazovat)
      "#{s.city}-#{s.long}".gsub(/\d+/){|m| '0'*(10 - m.size) + m }
    }
  end
  def new
    load_config
    @school ||= flash[:school] || Sosna::School.new
    @solver ||= flash[:solver]
    if ! @solver
      @solver= _prepare_new_solver
    end
    @agree = flash[:agree] || false
    _load_schools
  end

  def new_bonus
    @bonus = true
    new
    render :new
  end

  #def new_tnx end

  def _edit_want_send_first
    return false if !current_user.nil? && current_user.admin? && params[:send_first].nil?
    return true
  end

  def create
    load_config
    params.require(:sosna_solver).permit!
    is_admin =  !current_user.nil? && current_user.admin?

    school_id =  params[:school].delete :id

    send_first =  _edit_want_send_first()
    #@sosna_solver=params[:sosna_solver]
    #psc=@sosna_solver[:psc]
    #prvni=psc[0,3]
    #druhe=psc[-2,2]
    #pscnove=prvni+" "+druhe
    #@sosna_solver[:psc]=pscnove
    #params[:sosna_solver]=@sosna_solver
    solver = Sosna::Solver.new(params[:sosna_solver])

    is_bonus = solver.confirm_state == 'bonus'

    solver.valid?
    agree = ! params[:souhlasim].nil?
    solver.errors.add(:souhlasim, 'Je nutno souhlasit s podmínkami') if ! agree
    solver.errors.add(:email, 'je již registrován u jiného řešitele') if Sosna::Solver.where(email: solver.email, annual: @annual).exists? && !solver.email.empty?

    if solver.psc !~ /^\d{3} \d{2}$/ # pokud neni ve tvaru ^DDD DD$
      solver.psc=solver.psc.gsub(/[^\d]/, '')	# kazdou necislici nahradi ''-smaze
      if ! (solver.psc.length == 5)
        solver.errors.add(:psc, 'neobsahuje 5 číslic')  #hodi chybu pokud neobsahuje prave 5 cislic
      else
        solver.psc=solver.psc[0,3]+" "+solver.psc[-2,2] # prevede do tvaru ^DDD DD$
      end
    end

    solver.errors.add(:email, 'neexistující adresa') if !solver.email.empty? && !email_valid_mx_record?(solver.email)
    solver.errors.add(:birth, 'jsi příliš stár') if solver.errors[:birth].blank? && !solver.birth.empty? && (Date.parse(solver.birth) + 17.years) < Date.today
    solver.errors.add(:email, 'adresa nemůže být prázdná') if !is_admin && solver.email.empty?

    not_admin =  current_user.nil? ||  !current_user.admin?
    if not_admin
      solver.errors.add(:birth, 'nemůže být prázdné') if solver.birth.blank?
    end

    case school_id
     when 'none'
       solver.errors.add(:skola, 'Vyber školu ze seznamu nebo zadej novou')
     when 'jina'
      params.require(:sosna_school).permit!
      school = Sosna::School.new(params[:sosna_school])
     else
      school = Sosna::School.find(school_id)
    end

    if school.psc !~ /^\d{3} \d{2}$/ # pokud neni ve tvaru ^DDD DD$
      school.psc=school.psc.gsub(/[^\d]/, '')	# kazdou necislici nahradi ''-smaze
      if ! (school.psc.length == 5)
        school.errors.add(:psc, 'neobsahuje 5 číslic')  #hodi chybu pokud neobsahuje prave 5 cislic
      else
        school.psc=school.psc[0,3]+" "+school.psc[-2,2] # prevede do tvaru ^DDD DD$
      end
    end

    if school.nil? || school.invalid? || solver.errors.count > 0
        add_alert "Pozor: ve formuláři jsou chyby"
        school.id = -1 if school_id == 'jina'
        flash[:solver] = solver
        flash[:school] = school
        flash[:agree] = agree
        #Rails.logger.fatal(pp("school", solver.errors.messages))
        #Rails.logger.fatal(pp("solver", school.errors.messages)) if school
        return redirect_to :action => :new_bonus if is_bonus
        return redirect_to :action => :new
    end


    solver.school = school
    solver.annual = @annual

    user = User.find_by_email solver.email.downcase
    if !user
      if ! solver.email.empty?
        # create user by email

        # Are e-mail addresses case sensitive?
        #
        # Yes, according to RFC 2821, the local mailbox (the portion before @)
        # is considered case-sensitive. However, typically e-mail addresses are
        # not case-sensitive because of the difficulties and confusion it would
        # cause between users, the server, and the administrator.
        user =  User.new(email: solver.email.downcase, name: solver.name, last_name: solver.last_name, confirmation_sent_at: Time.now,  roles: [:user])

        user.confirm
        user.send_first_login_instructions  if send_first
        solver.user_id = user.id
        user.save
      end
    else
      solver.user_id = user.id
      send_first = false
    end

    # some test
    school.save if school.id.nil?
    solver.save
    redirect_to :action => :create_tnx, :send_first =>  send_first
  end

  def create_tnx
  end

  def user_solver_confirm
    @solver = Sosna::Solver.where(:user_id => current_user.id, :annual => @config[:annual]).take
    @solver_is_current_user = true
    if ! @solver
      add_alert "Pozor: zatím nejsi letošním řešitelem, nejprve vyplň přihlašku!"
      return redirect_to :controller => :solver , :action => :new
    end
    if @solver.confirm_state != 'next'
      add_alert "Uživatel již návratku potvrdil"
      redirect_to :sosna_solutions_user
    end
    @school = @solver.school
    _load_schools
  end

  def show
    id = params[:id]
    @solver = id ? Sosna::Solver.find(id) : Sosna::Solver.new
    @school = @solver.school
    if id
     @solutions = Sosna::Solution.where(:solver_id => id).all
    end
    load_config
    _load_schools
  end

  def update_confirm
    log "update_confirm"
    @solver = Sosna::Solver.where(:user_id => current_user.id, :annual => @config[:annual]).take
    sol_id = params[:sosna_solver][:id].to_i
    log "sid:#{sol_id} sid2:#{@solver.id} #{sol_id == @solver.id} #{!@solver.nil? && sol_id == @solver.id}"
    if !@solver.nil? && sol_id == @solver.id
      log "->update"
      update
    else
      add_alert "Wrong solver"
      log "wrong solver"
      redirect_to :sosna_solutions_user
    end
  end

  def update
    Rails.logger.fatal("A0")
    params.require(:sosna_solver).permit!
    sr = params[:sosna_solver]
    school_id = params[:school].delete :id

    Rails.logger.fatal("A1")

    begin
      school = Sosna::School.find(school_id)
    rescue
      begin
        Rails.logger.fatal("A2")
        params.require(:sosna_school).permit!
        school = Sosna::School.new(params[:sosna_school])
        school.save
      rescue
        school = nil
      end
    end

    Rails.logger.fatal("A3")

    sr.delete :user_id

    if sr[:id]
      solver = Sosna::Solver.find(sr[:id])
      solver.school = school
      solver.update_attributes(sr)
    else
      solver = Sosna::Solver.create(sr)
    end
    Rails.logger.fatal("A4")
    Rails.logger.fatal("A4.1")

    if !params[:is_confirm].nil?
       log "A4.5"
       solver.confirm_state = 'conf'
       solver.save
       add_success "Návratka potvrzena."
       return redirect_to :sosna_solutions_user
    end
    Rails.logger.fatal("A5")

    if _edit_want_send_first()
      user = User.find_by_email solver.email
      if !user.nil?
        user.send_first_login_instructions
        add_success "Zaslán uvítací email"
      end
    end
    redirect_to :action =>  :show , :id => solver.id
  end
  def _send_user_auto_creation_instructions(user)
       #user.send_confirmation_instructions
       user.generate_confirmation_token! if user.confirmation_token.nil?
       #user.devise_mailer.confirmation_instructions(user).deliver
       devise_mailer.devise_mail(user, :confirmation_instructions).deliver

  end
  def _prepare_new_solver
    return Sosna::Solver.new if current_user.nil?
    last_solver =  Sosna::Solver.find_by_user_id(current_user.id)
    return Sosna::Solver.new(:email => current_user.email.downcase) if last_solver.nil?
    new_solver = last_solver.clone
    delta = @annual.to_i - new_solver.annual.to_i
    new_solver.grade_num = new_solver.grade_num.to_i + delta
    new_solver.grade = _grade_plus(new_solver.grade,delta)
    return new_solver
  end
  def _grade_plus(grade, delta)

    cl =  %w(nila prima sekunda tercie kvarta kvinta sexta septima oktava)
    return "#{$1}#{cl[delta+1]}#{$2}" if grade =~ /^(.*)prima(.*)$/i
    return "#{$1}#{cl[delta+2]}#{$2}" if grade =~ /^(.*)sekunda(.*)$/i
    return "#{$1}#{cl[delta+3]}#{$2}" if grade =~ /^(.*)terice(.*)$/i
    return "#{$1}#{cl[delta+4]}#{$2}" if grade =~ /^(.*)kvarta(.*)$/i
    return "#{$1}#{cl[delta+4]}#{$2}" if grade =~ /^(.*)qarta(.*)$/i
    return "#{$1}#{cl[delta+5]}#{$2}" if grade =~ /^(.*)kvinta(.*)$/i
    return "#{$1}#{cl[delta+6]}#{$2}" if grade =~ /^(.*)sexta(.*)$/i
    return "#{$1}#{cl[delta+7]}#{$2}" if grade =~ /^(.*)septima(.*)$/i
    return "#{$1}#{cl[delta+8]}#{$2}" if grade =~ /^(.*)okt.va(.*)$/i

    ro = %w( i ii iii iv v vi vii viii ix )
    if grade =~ /^([ixv]+)(.)/i
      r, rest = $1, $2
      ri = ro.index(r.downcase)
      if ! ri.nil?
        r_plus = ro[ri+delta]
        return "#{r_plus.upcase}#{rest}" if ! r_plus.nil?
      end
    end

    if grade =~ /^([^\d]*)(\d+)(.*)$/
      prefix, id, rest = $1, $2, $3
      return "#{prefix}#{id.to_i + delta}#{rest}"
    end
    return grade
  end

  def aesop
    _aesop_init
    @aesop_url = 'https://pikomat.mff.cuni.cz/ovvp'
  end

  def _aesop_init
    load_config
    #@round_max = Sosna::Config.where(key: 'round') .take.value.to_i
    # FIXME:
    #@round_max = 6 if @round_max >= Sosna::Problem::BONUS_ROUND_NUM
  end

  def aesop_create
    _aesop_init

    @annual = params[:roc] || @annual
    @round_max = params[:se] || @round
    errors_to = @config[:aesop_errors_to];

    files = []
    dir = "ovvp"
    index_path = "ovvp.index.txt"
    (@round_max.to_i .. @round_max.to_i ).each do |round|

      file = "ovvp.#{@annual}.#{round}.txt"
      File.open("#{dir}/#{file}", 'w') do |f|
          f.write _aesop_print_round(@annual.to_i, round, errors_to)
      end
      files << file
      "#{@annual}.#{round}.txt"
    end
    File.open("#{dir}/#{index_path}", 'w') do |f|
      f.write(files.join("\n")+"\n")
    end
    add_success "created #{dir}/#{index_path}, #{files.map{|f| "#{dir}/#{f}"}.join(',')}.\n"
    redirect_to :sosna_solver_aesop
  end


# version   Verze formátu. Tato specifikace popisuje verzi 1.
# event   Identifikátor akce (např. ksp.rocnik.z)
# year    Rok, v němž se akce konala. Je-li akce spjata se školním rokem, patří sem první rok.
# date  Datum vytvoření exportu ve tvaru YYYY-MM-DD HH:MM:SS.
# errors-to   E-mailová adresa, na níž se mají odesílat zprávy o chybách při zpracování exportu.
# max-rank  Počet účastníků (povinné, pokud se část účastníků z nějakého důvodu neexportuje).
# max-points  Maximální možný počet získaných bodů.



# name    Křestní jméno. Může jich být více, oddělených mezerou.
# surname   Příjmení.
# street  Korespondenční adresa: ulice a domovní číslo. Pokud se jedná o obec bez ulic, pište prosím jen domovní číslo, případně název obce a domovní číslo.
# postcode  Korespondenční adresa: směrovací číslo. U českých a slovenských adres 5 číslic bez mezery.
# country   Korespondenční adresa: kód státu podle ISO 3166-1 (cz, sk, apod.). Na velikosti písmen nezáleží.
# fullname  Pokud se v adrese má na pozici jména vyskytnout něco jiného než
#            Jméno Příjmení, vložte to sem. To se dá použít, pokud chcete hezky formátovat
#            např. cizí jména, u nichž je zvykem uvádět příjmení jako první. Rozhodně se
#            cizí pořadí nepokoušejte simulovat prohozením položek name a surname.
#
# school      Identifikátor školy. Zatím jsou definované formáty „izo:XYZ“ (české
#             IZO), „sk:XYZ“ (slovenský kód školy), „aesop:XYZ“ (interní ID v AESOPovi),
#             „ufo“ (škola, kterou zatím neumíme identifikovat; takové záznamy by se měly
#             vyskytovat jen po velmi krátkou dobu).
# end-year    Rok očekávaného konce středoškolského studia.
# email       E-mailová adresa podle RFC 5322.
# rank        Pořadí ve výsledkovce. Pokud se více účastníků dělí o místo, patří sem nejmenší ze sdílených pořadí.
# points      Počet získaných bodů.
# spam-flag   „Y“ pokud účastník svolil k zasílání materiálů Matfyzu, „N“ pokud jsme se ho ptali a nesvolil. Prázdný řetězec znamená, že jsme se explicitně nezeptali.
# spam-date   Datum (YYYY-DD-MM), kdy jsme se dozvěděli hodnotu spam-flag-u.

  def _aesop_print_round(annual, round, errors_to)


    maturity_grade = 13
    date = DateTime.now.strftime('%Y-%m-%d %H:%M:%S')
    year = 2014 + annual - 30
    event = "pikomat.#{annual}"
    event = "pikomat.rocnik"
    comment = "Pikomat rocnik=#{annual} serie=#{round}"

    solvers = Sosna::Solver.where(annual: annual, is_test_solver: false)
    ex = []
    ex << ['version',     1]
    ex << ['year',        year]
    ex << ['event',       event]
    ex << ['errors-to',    errors_to]
    ex << ['date',        date]
    ex << ['max-rank',   solvers.count ]
    ex << ['max-points',  round * 30]
    ex << ['comment',  comment ]
    ex << []
    ex << ['id', 'name', 'surname', 'fullname', 'school', 'street', 'postcode', 'town', 'country', 'email', 'end-year', 'rank', 'points', 'spam-flag', 'spam-date',
           #'grade',
           ]

    solvers.each  do |solver|

      next if ['p.zahajska@yahoo.com', 'lux.filip@gmail.com'  ] .include? solver.email
      school = solver.school

      rank = 0
      points = 0

      res = Sosna::Result.where(annual: annual, round: round, solver_id: solver.id).take
      if res
        rank = res.rank
        points = res.score
      end

      if solver.grade_num.nil? || solver.grade_num.to_i == 0
        finish_year = ''
      else
        finish_year = solver.finish_year || ( year + 1 + maturity_grade - solver.grade_num.to_i )
        #finish_year = "#{finish_year}:#{solver.grade_num}"
        finish_year = "#{finish_year}"
      end

      spam_flag = 'Y'
      spam_date = solver.created_at.strftime('%Y-%m-%d')
      full_name = "#{solver.name} #{solver.last_name}"
      ex << [  solver.id, solver.name, solver.last_name, full_name,
               school.nil? ? 'ufo' : school.universal_id,
               "#{solver.street} #{solver.num}", (solver.psc||'').gsub(' ',''), solver.city,
               'cz', solver.email,
               finish_year,
               points, rank,
               spam_flag, spam_date,
               #solver.grade_num,
               ]
    end
 
    return ex.map{  |row| row.join("\t") + "\n" }.join

  end


end
