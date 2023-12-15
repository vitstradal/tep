##
# Controller pro "účastnické účty", neboli účty umožňující jezdit na akce
#
class Act::ParticipantsController < ActController  

  ##
  # GET /participants/index
  #
  # Úvodní stránka k účastnickým účtům obecně
  #
  # *Params*
  # grade: které ročníky chceme zobrazit
  # role: které role (účastník/org) chceme zobrazit
  #
  # *Provides*
  # @participants:: účastnické účty, které budou zobrazeny
  #
  def index
    @grade = params[:grade].nil? ? "ev" : params[:grade]
    @role = params[:role].nil? ? "p" : params[:role]

    case @grade
    when "ev"
      @participants = Act::Participant.all()
    when "young"
      @participants = Act::Participant.where('grade < ?', Act::Participant::YOUNGEST_TO_FILTER)
    when "old"
      @participants = Act::Participant.where('grade > ?', Act::Participant::YOUNGEST_TO_FILTER)
    else
      @participants = Act::Participant.where(grade: @grade)
    end

    if @role == 'p'
      @participants = @participants.select{ |s| ! s.org? }
    else
      @participants = @participants.select{ |s| s.org? }
    end
  end

  ##
  # GET /participants/:participant_id/show
  #
  # Úvodní stránka k vybranému účastníkovi
  #
  # *Params*
  # participant_id:: Zobrazovaný účastnický účet
  #
  # *Provides*
  # @my_events:: akce, na které jsem přihlášený s tím, že vím, že na ně chci jet
  # @maybe_events:: akce, na které jsem přihlášený s tím, že ještě vím, jestli na ně chci jet
  # @no_events:: akce, na které jsem přihlášený s tím, že vím, že na ně nepojedu
  # @not_my_events:: akce, na které zatím nejsem vůbec přihlášený
  #
  def show
    @participant = Act::Participant.find_by(id: params[:participant_id])

    return render :not_found if @participant.nil?

    unless (can? :show_other, Act::Participant) || (Act::Participant::participant_id(current_user) == params[:participant_id].to_i)
      @msg = "Tento účastnických účet není tvůj a bohužel nemáš práva na zobrazování účtů ostatních."
      return render :not_allowed
    end

    args_my_events, _ = Act::Event::generate_sql(Act::Participant.find(params[:participant_id]), "ev", "yes")
    args_maybe_events, _ = Act::Event::generate_sql(Act::Participant.find(params[:participant_id]), "ev", "maybe")
    args_no_events, _ = Act::Event::generate_sql(Act::Participant.find(params[:participant_id]), "ev", "no")
    args_not_my_events, _ = Act::Event::generate_sql(Act::Participant.find(params[:participant_id]), "ev", "nvt")

    @my_events = Act::Event.find_by_sql(args_my_events)
    @maybe_events = Act::Event.find_by_sql(args_maybe_events)
    @no_events = Act::Event.find_by_sql(args_no_events)
    @not_my_events = Act::Event.find_by_sql(args_not_my_events)
  end

  ##
  # GET /participants/new
  #
  # Formulář pro nový účastnický účet
  #
  # *Provides*
  # @participant:: nový účastnický účet
  #
  # *Redirect* act_participant_path
  def new
    
    return render :log_in_to_new if current_user.nil?

    return redirect_to act_participant_path(current_user.participant) if  Act::Participant::has_participant?(current_user) 

    @participant = Act::Participant.new(:user_id => current_user.id, :name => current_user.name, :last_name => current_user.last_name, :email => current_user.email)
  end

  ##
  # GET /participants/new_complet
  #
  # Formulář pro nový účastnický účet s tím, že se současně vytvoří i uživatelský účet
  #
  # *Provides*
  # @participant:: nový účastnický účet
  # new_complet:: že to opravdu chceme i s tím uživatelským účtem
  #
  def new_complet
    return redirect_to act_participant_path(current_user.participant) if Act::Participant::has_participant?(current_user)

    @new_complet = true
    @participant = Act::Participant.new()
    render :new
  end

  ##
  #  POST /act/participants/create
  #
  # Vytvoří nový účastnický účet
  #
  # *Params*
  # participant_params[]:: parametry upravovaného účastnického účtu
  #
  # *Redirect* @participant
  def create
    if Act::Participant::has_participant?(current_user) && (! can? :create_other, Act::Participant)
      @msg = "Ty už svůj účastnických účet máš."
      return render :not_allowed
    end

    if params[:participant][:user_id] != current_user.id.to_s && (! can? :create_other, Act::Participant)
      @msg = "Nemáš práva na vytváření účastnických účtů ostatním užvatelům."
      return render :not_allowed
    end

    @participant = Act::Participant.new(participant_params)
    @user_id = current_user.id

    agree = params[:souhlasim]
    @participant.errors.add(:souhlasim, 'Je nutno souhlasit s podmínkami') if ! agree

    if @participant.errors.count == 0 && @participant.save(participant_params)
      redirect_to @participant
    else
      add_alert "Pozor: ve formuláři jsou chyby"
      render :new, status: :unprocessable_entity
    end
  end

  ##
  #  POST /act/participants/create
  #
  # Vytvoří nový účastnický účet s tím, že se současně vytvoří i uživatelský účet
  #
  # *Params*
  # participant_params[]:: parametry upravovaného účastnického účtu
  #
  # *Redirect* :create_tnx
  def create_complet
    if Act::Participant::has_participant?(current_user) && (! can? :create_other, Act::Participant)
      @msg = "Ty už svůj účastnických účet máš."
      return render :not_allowed
    end

    @participant = Act::Participant.new(participant_params)

    agree = ! params[:souhlasim].nil?
    @participant.errors.add(:souhlasim, 'Je nutno souhlasit s podmínkami') if ! agree

    if @participant.errors.count != 0 || @participant.invalid?
      add_alert "Pozor: ve formuláři jsou chyby"
      return render :new, status: :unprocessable_entity
    end

    send_first = true
    user = User.find_by_email @participant.email.downcase
    if !user
      # create user by email
      # Are e-mail addresses case sensitive?
      #
      # Yes, according to RFC 2821, the local mailbox (the portion before @)
      # is considered case-sensitive. However, typically e-mail addresses are
      # not case-sensitive because of the difficulties and confusion it would
      # cause between users, the server, and the administrator.
      user =  User.new(email: @participant.email.downcase, name: @participant.name, last_name: @participant.last_name, confirmation_sent_at: Time.now,  roles: [:user])

      user.confirm
      user.send_first_login_instructions(false)
      @participant.user_id = user.id
      user.save
    else
      @participant.user_id = user.id
      send_first = false
    end

    @participant.save(participant_params)
    redirect_to :action => :create_tnx, :send_first => send_first
  end

  ##
  #  GET  /sosna/solver/tnx
  #
  # stránka s poděkováním při registraci nového řešitele
  def create_tnx

  end

  ##
  #  GET /act/participants/:participant_id/edit
  #
  # Formulář na úpravu účastnického účtu
  #
  # *Params*
  # participant_id:: účastnický účet, který upravujeme
  #
  # *Provides*
  # @participant:: účastnický účet, který upravujeme
  #
  def edit
    if current_user.nil? || ((! Act::Participant::has_participant?(current_user) || (Act::Participant::has_participant?(current_user) && params[:participant_id] != current_user.participant.id.to_s)) && (! can? :update_other, Act::Participant))
      @msg = "Nemáš práva na upravování účastnických účtů ostatních užvatelů."
      return render :not_allowed
    end

    @participant = Act::Participant.find_by(id: params[:participant_id])
    if @participant.nil?
      return render :not_found
    end
  end

  ##
  #  PATCH /act/participants/:participant_id
  #
  # Uprav daný účastnický účet
  #
  # *Params*
  # participant_id:: účastnický účet, který upravujeme
  # participant_params parametry účastnického účtu
  #
  # *Provides*
  # @participant:: akce, účastnický účet, který upravujeme
  #
  # *Redirect* @participant
  #
  def update
    if current_user.nil? || ((! Act::Participant::has_participant?(current_user) || (Act::Participant::has_participant?(current_user) && params[:participant_id] != current_user.participant.id.to_s)) && (! can? :update_other, Act::Participant))
      @msg = "Nemáš práva na upravování účastnických účtů ostatních uživatelů."
      return render :not_allowed
    end

    @participant = Act::Participant.find_by(id: params[:participant_id])

    return render :not_found if @participant.nil?

    if @participant.update(participant_params)
      redirect_to @participant
    else
      render :edit, status: :unprocessable_entity
    end
  end

  ##
  #  POST /act/participants/:participant_id/confirm_delete
  #
  # Potvrzení, že ten uživatel ten účastnický účet fakt chce vymazat
  #
  # *Params*
  # participant_id:: účastnický účet, který mažeme
  #
  # *Provides*
  # @participant:: akce, účastnický účet, který mažeme
  #
  def confirm_delete
    @participant = Act::Participant.find_by(id: params[:participant_id])
    if current_user.nil? || (@participant.user_id != current_user.id && (! can? :delete_other, Act::Participant))
      @msg = "Nemáš práva na mazání účastnických účtů ostatních uživatelů."
      return render :not_allowed
    end
  end

  ##
  #  POST /act/participants/:participant_id/delete
  #
  # Smazání uživatelského účtu
  #
  # *Params*
  # participant_id:: účastnický účet, který mažeme
  #
  # *Provides*
  # @participant:: akce, účastnický účet, který mažeme
  #
  # *Redirect* root_path nebo act_participants_path
  #
  def delete
    @participant = Act::Participant.find_by(id: params[:participant_id])
    if current_user.nil? || (@participant.user_id != current_user.id && (! can? :delete_other, Act::Participant))
      @msg = "Nemáš práva na mazání účastnických účtů ostatních uživatelů."
      return render :not_allowed
    end

    deleting_myself = @participant.user_id == current_user.id
    @participant.destroy
    
    if deleting_myself
      redirect_to root_path
    else
      redirect_to act_participants_path
    end
  end

  ##
  #  POST act/participants/create_other
  #
  # Vytvoří nový účastnický účet někmu jinému, než aktuálnímu uživateli
  #
  # *Params*
  # participant_params[]:: parametry upravovaného účastnického účtu
  #
  # *Redirect* params[:path]
  def create_other
    unless can? :create_other, Act::Participant
      @msg = "Na vytváření účastnických účtů ostatním uživatelům nemáš práva."
      return render :not_allowed
    end

    user = User.find_by(id: params[:user_id])
    participant = Act::Participant.new(:user_id => user.id, :name => user.name, :last_name => user.last_name, :email => user.email, :activated => "desact")
    participant.save(validate: false)
    redirect_to params[:path]
  end

  ##
  #  GET /act/participants/new_year
  #
  # Zvýší ročníky všech účastnických účtů o jeden
  #
  # *Redirect* act_participants_path
  def new_year
    if current_user.nil? || ! current_user.admin?
      @msg = "Na zahájení nového ročníků nemáš právo."
      return render :not_allowed
    end

    Act::Participant.find_each do |s|
      if s.grade
        s.grade += 1
        s.save
      end
    end
    redirect_to act_participants_path
  end

  ##
  #  GET /act/participants/previous_year
  #
  # Sníží ročníky všech účastnických účtů o jeden
  #
  # *Redirect* act_participants_path
  def previous_year
    if current_user.nil? || ! current_user.admin?
      @msg = "Na vrácení ročníků nemáš právo."
      return render :not_allowed
    end

    Act::Participant.find_each do |s|
      if s.grade
        s.grade -= 1
        s.save
      end
    end
    redirect_to act_participants_path
  end

  private
    def participant_params
      params.require(:participant).permit! #TODO
    end
end
