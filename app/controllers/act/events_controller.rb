##
# Controller pro přihlašování se na akce
#
# VISIBLE_STATUSES:
# 'everyone'
# 'user'
# 'org'

require 'pp'

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

    args_future, args_past = Act::Event::generate_sql(Act::Scout::get_scout(current_user), @event_category, @enroll_status)

    @future_events = Act::Event.find_by_sql(args_future)
    @past_events = Act::Event.find_by_sql(args_past)
  end

  def show
    return unless _find_event(params[:event_id])

    if Act::Scout::scouts?(current_user)
      @event_participant = Act::EventParticipant.find_by("event_id=? AND scout_id=?", params[:event_id], Act::Scout::scout_id(current_user))
      unless @event_participant
        @event_participant = Act::EventParticipant.new
      end
    end

    @num_p_yes = @event.num_signed("yes", false, true)

    @already_happened = @event.event_end < Date.current
  end

  def enroll
    @event_participant = Act::EventParticipant.find_by([params[:event_id], Act::Scout::scout_id(current_user)])
    if @event_participant

      participant_copy = @event_participant.dup
      @event_participant.update_chosen()

      if @event_participant.update(participant_params)
        if Act::EventParticipant::mail_change?(participant_copy, @event_participant)
          _send_bonz_org(@event_participant.event.bonz_org, @event_participant, false)
          _send_bonz_parent(@event_participant.scout.parent_email, @event_participant, false)
        end

        redirect_to @event_participant.event
      else
        render :show, status: :unprocessable_entity
      end
    else
      @event_participant = Act::EventParticipant.new(participant_params)    
      @event_participant.update_chosen()
      if @event_participant.save
        _send_bonz_org(@event_participant.event.bonz_org, @event_participant, true)
        _send_bonz_parent(@event_participant.scout.parent_email, @event_participant, true)

        redirect_to Act::Event.find(params[:event_id])
      else
        render :show, status: :unprocessable_entity
      end
    end
  end

  def new
    if not can? :create, Act::Event
      render 'permission_denied', :locals => { :desired => "vytvářet nové" }
      return
    end

    @event = Act::Event.new
  end

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

  def edit
    if not can? :create, Act::Event
      render 'permission_denied', :locals => { :desired => "editovat existující " }
      return
    end

    return unless _find_event(params[:event_id])
  end

  def edit_participants
    return unless _find_event(params[:event_id])

    if not can? :update, Act::EventParticipant
      render 'permission_denied', :locals => { :desired => "editovat ostatní účastníky na " }
      return
    end

    @edit_participants = true
    render :show
  end

  def edit_invitations
    return unless _find_event(params[:event_id])

    @chosen = params[:chosen].nil? ? "ev" : params[:chosen]
    @role = (params[:role].nil? or params[:role] == 'p' or ! current_user.admin?) ? "p" : "o"

    @scouts = Act::Scout::find_by_invitation(@event, @chosen, @role)

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

  def enroll_others
    return unless _find_event(params[:event_id])

    if !(can? :create_other, Act::EventParticipant)
       render 'permission_denied', :locals => { :desired => "přihlašovat ostatní účastníky na " }
       return
    end

    @chosen = params[:chosen] || "ev"
    @role = params[:role] || "p"
    @status = params[:status] || "ev"

    @scouts = Act::Scout::find_by_participation(@event, @status, @chosen, @role)

    render :enroll_others
  end

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

  def delete 
    if not can? :create, Act::Event
      render 'permission_denied', :locals => { :desired => "mazat existující " }
      return
    end

    return unless _find_event(params[:event_id])
    @event.destroy

    redirect_to act_events_path
  end

  def filter
    redirect_to act_events_filter_path(params[:event_category], params[:enroll_status])
  end

  def display_scouts
    if !(can? :show_other, Act::Scout)
      render 'not_allowed_to_show_others'
      return
    end

    return unless _find_event(params[:event_id])

    @event_participants = Act::EventParticipant.find_by_sql(["SELECT * FROM act_event_participants WHERE event_id = ?", params[:event_id]])
    @filter_hashes = params[:filter_hashes].nil? ? Act::Scout::ATTR_BOOL_TABLE : params[:filter_hashes]
  end

  private
    def event_params
      params.require(:event).permit!
    end

    def participant_params
      params.require(:event_participant).permit(:event_id, :scout_id, :status, :note, :place, :mass, :scout_info)
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
      new_txt = is_new ? "Přihlášení" : "Změna přihlášky"
      if event_participant.org?
        person_txt = event_participant.male? ? "Orga" : "Orgyně"
      else
        person_txt = event_participant.male? ? "Účastníka" : "Účastnice"
      end

      Tep::Mailer.event_bonz_org(bonz_email, 'PIKOMAT: ' + new_txt + person_txt + "na akci", event_participant, is_new).deliver_later
    end
  end

  def _send_bonz_parent(bonz_email, event_participant, is_new)
    # mail rodici ucastnika
    if !bonz_email.nil? and bonz_email != ""
      new_txt = is_new ? "Přihlášení" : "Změna přihlášky"
      gender_txt = event_participant.male? ? "Vašeho syna" : "Vaší dcery"
      Tep::Mailer.event_bonz_parent(bonz_email, 'PIKOMAT: ' + new_txt + gender_txt + "na akci", event_participant, is_new).deliver_later
    end
  end

end
