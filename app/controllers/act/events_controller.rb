##
# Controller pro přihlašování se na akce
#
# VISIBLE_STATUSES:
# 'everyone'
# 'user'
# 'org'

class Act::EventsController < ActController

  ##
  # GET /event/index
  #
  # Úvodní stránka k přihlašování na akce obecně
  #
  # *Provides*
  # @future_events::     všechny akce, které se budou konat (seřazené)
  # @past_evens::        všechny akce, které už se konaly (seřazené)
  # @event_category::    o jaký typ akce se jedná? (Act::Event::CATEGORIES)
  # @enroll_status::     jakým způsobem jsem na tu akci přihlášený? (yes, no, maybe) + (ev, nvt)
  #
  def index
    @event_category = params[:event_category]
    if @event_category.nil?
      @event_category = "ev"
    end

    @enroll_status = params[:enroll_status]
    if @enroll_status.nil?
      @enroll_status = "ev"
    end

    args_future, args_past = Act::Event::generate_sql(Act::Participant::get_participant(current_user), @event_category, @enroll_status)

    @future_events = Act::Event.find_by_sql(args_future)
    @past_events = Act::Event.find_by_sql(args_past)
  end

  ##
  # GET /event/:event_id/show
  #
  # Úvodní stránka k vybrané akci
  #
  # *Params*
  # event_id:: O jakou akci se jedná
  #
  # *Provides*
  # *num_p_yes:: kolik účastníků (nikoliv náhradníků) je přihlášných s tím, že si jsou jistí, že jedou
  # @already_happened:: jestli se ten event již odehrál
  # @participants_yes:: účastníci (nikoliv náhradníci), kteří jedou
  # @participants_maybe:: účastníci (nikoliv náhradníci), kteří si nejsou jistí
  # @participants_no:: účastníci (nikoliv náhradníci), kteří nejedou
  # @substitutes_yes:: náhradníci (nikoliv účastníci), kteří jedou
  # @substitutes_maybe:: náhradníci (nikoliv účastníci), kteří si nejsou jistí
  # @substitutes_no:: náhradníci (nikoliv účastníci), kteří nejedou
  #
  def show
    return unless _find_event(params[:event_id])

    if Act::Participant::has_participant?(current_user)
      @event_participant = Act::EventParticipant.find_by("event_id=? AND participant_id=?", params[:event_id], Act::Participant::participant_id(current_user))
      unless @event_participant
        @event_participant = Act::EventParticipant.new
      end
    end

    @num_p_yes = @event.num_signed("yes", false, true)

    @already_happened = @event.event_end < Date.current

    _get_participants()
  end

  ##
  # POST /event/:event_id/enroll
  #
  # Vytvoří nebo upraví přihlášku
  #
  # *Params*
  # event_id:: O jakou akci se jedná
  # event_participant_params[]:: parametry přihlášky
  #
  # *Provides*
  # @event_participant:: daná přihláška
  # 
  # *Redirect* @event_participant.event
  #
  def enroll
    @event_participant = Act::EventParticipant.find_by(event_id: params[:event_id], participant_id: Act::Participant::participant_id(current_user))
    if @event_participant
      participant_copy = @event_participant.dup
      @event_participant.update_chosen()

      if @event_participant.update(event_participant_params)
        if Act::EventParticipant::mail_change?(participant_copy, @event_participant)
          _send_bonz_org(@event_participant.event.bonz_org, @event_participant, false)
          _send_bonz_parent(@event_participant.participant.parent_email, @event_participant, false)
        end
        redirect_to @event_participant.event
      else
        render :show, status: :unprocessable_entity
      end
    else
      @event_participant = Act::EventParticipant.new(event_participant_params)    
      @event_participant.update_chosen()
      if @event_participant.save
        _send_bonz_org(@event_participant.event.bonz_org, @event_participant, true)
        _send_bonz_parent(@event_participant.participant.parent_email, @event_participant, true)
        redirect_to Act::Event.find(params[:event_id])
      else
        render :show, status: :unprocessable_entity
      end
    end
  end

  ##
  # GET /event/new
  #
  # Formulář pro novou akci
  #
  # *Provides*
  # @event:: nová akce
  #
  def new
    if not can? :create, Act::Event
      render 'permission_denied', :locals => { :desired => "vytvářet nové" }
      return
    end

    @event = Act::Event.new
  end

  ##
  #  POST /act/events/create
  #
  # Vytvoří novou akci
  #
  # *Params*
  # event_params[]:: parametry upravované akce
  #
  # *Redirect* @event
  def create
    if not can? :create, Act::Event
      render 'permission_denied', :locals => { :desired => "vytvářet nové " }
      return
    end

    @event = Act::Event.new(event_params)

    if @event.save
      redirect_to @event
    else
      render :new, status: :unprocessable_entity
    end
  end


  ##
  #  GET /act/events/:event_id/edit
  #
  # Formulář na úpravu akce
  #
  # *Params*
  # event_id:: akce, kterou upravujeme
  #
  # *Provides*
  # @event:: akce, kterou upravujeme
  #
  def edit
    if not can? :create, Act::Event
      render 'permission_denied', :locals => { :desired => "editovat existující " }
      return
    end

    return unless _find_event(params[:event_id])
  end

  ##
  #  GET /act/events/:event_id/edit_participants
  #
  # Formulář na úpravu účastníků dané akce
  #
  # *Params*
  # event_id:: akce, kterou upravujeme
  #
  # *Provides*
  # @event:: akce, kterou upravujeme
  # @participants_yes:: účastníci (nikoliv náhradníci), kteří jedou
  # @participants_maybe:: účastníci (nikoliv náhradníci), kteří si nejsou jistí
  # @participants_no:: účastníci (nikoliv náhradníci), kteří nejedou
  # @substitutes_yes:: náhradníci (nikoliv účastníci), kteří jedou
  # @substitutes_maybe:: náhradníci (nikoliv účastníci), kteří si nejsou jistí
  # @substitutes_no:: náhradníci (nikoliv účastníci), kteří nejedou
  # @edit_participants:: flag, že chceme účastnické přihlášky upravovat
  # *Render* :show
  #
  def edit_participants
    return unless _find_event(params[:event_id])

    if not can? :update, Act::EventParticipant
      render 'permission_denied', :locals => { :desired => "editovat ostatní účastníky na " }
      return
    end

    _get_participants()

    @edit_participants = true
    render :show
  end

  ##
  #  GET /act/events/:event_id/edit_invitations/(:chosen)/(:role)
  #
  # Formulář na úpravu pozvánek na danou akci
  #
  # *Params*
  # event_id:: akce, kterou upravujeme
  # chosen:: filtruj podle pozvaných účastníků vs náhradníků vs nepozvaných
  # role:: filtruj podle účastínků vs orgů
  #
  # *Provides*
  # @event:: akce, kterou upravujeme
  # @chosen:: filtruj podle pozvaných účastníků vs náhradníků vs nepozvaných
  # @role:: filtruj podle účastínků vs orgů
  # @participants:: vyfiltrované účastnické účty
  #
  def edit_invitations
    return unless _find_event(params[:event_id])

    @chosen = params[:chosen].nil? ? "ev" : params[:chosen]
    @role = (params[:role].nil? or params[:role] == 'p' or ! current_user.admin?) ? "p" : "o"

    @participants = Act::Participant::find_by_invitation(@event, @chosen, @role)

    if (can? :read, Act::EventInvitation) and !(can? :create, Act::EventInvitation)
      @editing = false
      render :edit_invitations
      return
    end

    if !(can? :read, Act::EventInvitation)
      render 'permission_denied', :locals => { :desired => "zobrazovat ani editovat pozvánky na " }
      return
    end

    @editing = true
    render :edit_invitations
  end

  ##
  #  GET /act/events/:event_id/enroll_others/(:status)/(:chosen)/(:role)
  #
  # Formulář na přihlášní (přp. změny stavu přihlášení) nových účastníků na danou akci
  #
  # *Params*
  # event_id:: akce, kterou upravujeme
  # status:: filtruj podle toho, jestli daný účastník jede/neví/nejde/je nepřihlášený
  # chosen:: filtruj podle pozvaných účastníků vs náhradníků vs nepozvaných
  # role:: filtruj podle účastínků vs orgů
  #
  # *Provides*
  # @event:: akce, kterou upravujeme
  # @chosen:: filtruj podle pozvaných účastníků vs náhradníků vs nepozvaných
  # @role:: filtruj podle účastínků vs orgů
  # @chosen:: filtruj podle pozvaných účastníků vs náhradníků vs nepozvaných
  # @participants:: vyfiltrované účastnické účty
  #
  def enroll_others
    return unless _find_event(params[:event_id])

    if !(can? :create_other, Act::EventParticipant)
       render 'permission_denied', :locals => { :desired => "přihlašovat ostatní účastníky na " }
       return
    end

    @chosen = params[:chosen] || "ev"
    @role = params[:role] || "p"
    @status = params[:status] || "ev"

    @participants = Act::Participant::find_by_participation(@event, @status, @chosen, @role)

    render :enroll_others
  end

  ##
  #  PATCH /act/events/:event_id
  #
  # Uprav danou akci
  #
  # *Params*
  # event_id:: akce, kterou upravujeme
  # event_params parametry akce, kterou upravujeme
  #
  # *Provides*
  # @event:: akce, kterou upravujeme
  #
  # *Redirect* @event
  #
  def update
    if not can? :create, Act::Event
      render 'permission_denied', :locals => { :desired => "editovat existující " }
      return
    end

    return unless _find_event(params[:event_id])

    if @event.update(event_params)
      redirect_to @event
    else
      render :edit, status: :unprocessable_entity
    end
  end

  ##
  #  POST /act/event/:event_id/delete
  #
  # Smaže akci
  #
  # *Params*
  # event_id:: id akce
  #
  # *Redirect* act_events_path
  def delete 
    if not can? :create, Act::Event
      render 'permission_denied', :locals => { :desired => "mazat existující " }
      return
    end

    return unless _find_event(params[:event_id])
    @event.destroy

    redirect_to act_events_path
  end

  ##
  #  POST /act/events/filter
  #
  # Pomocná funkce pro funkci filter
  #
  # *Params*
  # event_category:: typ akce
  # enroll_status:: jakým způsobem tam jsem přihlášený
  #
  # *Redirect* act_events_filter_path
  def filter
    redirect_to act_events_filter_path(params[:event_category], params[:enroll_status])
  end

  ##
  #  GET /act/events/:event_id/display_participants
  #
  # Způsob hromadného zobrazení účastníků spolu s některými jejich informacemi
  #
  # *Params*
  # event_id:: akce, kterou upravujeme
  # filter_hasehs[]:: které informace chceme uživateli zobrazit
  #
  # *Provides*
  # @event:: akce, kterou upravujeme
  # @parts_yes:: účastníci (nikoliv náhradníci), kteří jedou
  # @parts_maybe:: účastníci (nikoliv náhradníci), kteří si nejsou jistí
  # @parts_no:: účastníci (nikoliv náhradníci), kteří nejedou
  # @substitutes_yes:: náhradníci (nikoliv účastníci), kteří jedou
  # @substitutes_maybe:: náhradníci (nikoliv účastníci), kteří si nejsou jistí
  # @substitutes_no:: náhradníci (nikoliv účastníci), kteří nejedou
  # @orgs_yes:: orgové, kteří jedou
  # @orgs_maybe:: orgové, kteří si nejsou jistí
  # @orgs_no:: orgové, kteří nejedou
  # @filter_hasehs[]:: které informace chceme uživateli zobrazit
  # 
  def display_participants
    if !(can? :show_other, Act::Participant)
      render 'not_allowed_to_show_others'
      return
    end

    return unless _find_event(params[:event_id])

    _get_participants()

    _filter_orgs()
    _filter_parts()

    @filter_hashes = params[:filter_hashes].nil? ? Act::Participant::ATTR_BOOL_TABLE : params[:filter_hashes]
  end

  private
    def event_params
      params.require(:event).permit!
    end

    def event_participant_params
      params.require(:event_participant).permit!#(:event_id, :participant_id, :status, :note, :place, :mass, :participant_info)
    end

    def _find_event(event_id)
      @event = Act::Event.find_by(id: event_id)
      if @event.nil?
        render :not_found
        return false
      end

      if @event.event_visible?(current_user)
        return true
      else
        render :not_allowed_to_show
        return false
      end
    end

  def _send_bonz_org(bonz_email, event_participant, is_new)
    # mail h-orgovi akce
    if !bonz_email.nil? and bonz_email != ""
      new_txt = is_new ? "Přihlášení " : "Změna přihlášky "
      if event_participant.org?
        person_txt = event_participant.male? ? "orga " : "Orgyně "
      else
        person_txt = event_participant.male? ? "účastníka" : "Účastnice"
      end

      Act::Mailer.event_bonz_org(bonz_email, 'PIKOMAT: ' + new_txt + person_txt + "na akci", event_participant, is_new).deliver_later
    end
  end

  def _send_bonz_parent(bonz_email, event_participant, is_new)
    # mail rodici ucastnika
    if !bonz_email.nil? and bonz_email != ""
      new_txt = is_new ? "Přihlášení " : "Změna přihlášky "
      gender_txt = event_participant.male? ? "Vašeho syna " : "Vaší dcery "
      Act::Mailer.event_bonz_parent(bonz_email, 'PIKOMAT: ' + new_txt + gender_txt + "na akci", event_participant, is_new).deliver_later
    end
  end

  def _get_participants()
    @participants_yes = Act::EventParticipant.where(event_id: @event.id).where(status: "yes").where(chosen: "participant")
    @participants_maybe = Act::EventParticipant.where(event_id: @event.id).where(status: "maybe").where(chosen: "participant")
    @participants_no = Act::EventParticipant.where(event_id: @event.id).where(status: "no").where(chosen: "participant")

    @substitutes_yes = Act::EventParticipant.where(event_id: @event.id).where(status: "yes").where(chosen: "substitute")
    @substitutes_maybe = Act::EventParticipant.where(event_id: @event.id).where(status: "maybe").where(chosen: "substitute")
    @substitutes_no = Act::EventParticipant.where(event_id: @event.id).where(status: "no").where(chosen: "substitute")
  end

  def _filter_orgs()
    @orgs_yes = @participants_yes.select{ |p| p.participant.org? }
    @orgs_maybe = @participants_maybe.select{ |p| p.participant.org? }
    @orgs_no = @participants_no.select{ |p| p.participant.org? }
  end

  def _filter_parts()
    @parts_yes = @participants_yes.select{ |p| ! p.participant.org? }
    @parts_maybe = @participants_maybe.select{ |p| ! p.participant.org? }
    @parts_no = @participants_no.select{ |p| ! p.participant.org? }
  end

end
