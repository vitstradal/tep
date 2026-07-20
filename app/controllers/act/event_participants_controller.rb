class Act::EventParticipantsController < ActController

  ##
  #  POST /act/event_participants/:event_id/enroll_other
  #
  # Daného účastníka přihlásí na danou akci. Případně ho z té akce odstraní, pokud je parametr :delete nataven na "true"
  #
  # *Params*
  # event:id:: událost, ke které se pozvánka vztahuje
  # participant_id:: účastnický účet, ke kterému se pozvánka vztahuje
  # chosen:: jestli h chceme přihlásit jako účastníka nebo náhradníka
  # delete:: jestli ho chceme smazat
  #
  # *Redirect* params[:path]  ... vzhledem k tomu, že tato metoda může být volána z různých míst a vzhledem k tomu, že chceme,
  # abychom nás to vždy přesměrovalo někam rozumně, je cílová cesta předávána jako argument
  def enroll_other
    participant = Act::EventParticipant.find_by(event_id: params[:event_id], participant_id: params[:participant_id])

    return render :not_allowed, locals: { :desired => "vytvářeti " } if participant.nil? && (! can? :create_other, Act::EventParticipant)

    if current_user.nil? || (! can? :update_other, Act::EventParticipant) && @participant.participant.user.id != current_user.id
      return render :not_allowed, locals: { desired: "upravovati " }
    end

    if participant.nil?
      is_creating = true
      participant = Act::EventParticipant.new
      participant.event_id = params[:event_id]
      participant.participant_id = params[:participant_id]
      participant.status = "yes"
      participant.chosen = params[:chosen]
    elsif params[:delete] != "true"
      is_creating = false
      if params[:chosen] && params[:chosen] != participant.chosen
        participant.chosen = params[:chosen]
      end
    end

    if params[:delete] == "true"
      participant.destroy
      add_success "Přihláška na akci byla úspěšně smazána"
      redirect_to params[:path]
      return
    end

    if participant.save
      add_success "Přihláška na akci byla úspěšně " + (is_creating ? "vytvořena" : "změněna")
      redirect_to params[:path]
    else
      @error_messages = []
      participant.errors.full_messages.each do |msg|
        @error_messages.append(msg)
      end

      _find_event(params[:event_id])
      @chosen = "ev"
      @role = "p"
      @status = "ev"
      @participants = Act::Participant::find_by_participation(@event, @status, @chosen, @role)

      render "act/events/enroll_others", status: :unprocessable_entity
    end
  end

  ##
  #  POST /act/event_participants/:event_id/update
  #
  # Upraví přihlášku daného účastníka na danou akci
  #
  # *Params*
  # event:id:: událost, ke které se pozvánka vztahuje
  # participant_id:: účastnický účet, ke kterému se pozvánka vztahuje
  #
  # *Provides*
  # @event_participant:: kterou přihlášku upravujeme
  #
  # *Redirect* act_event_edit_participants_path
  def update
    @event_participant = Act::EventParticipant.find_by(event_id: params[:event_id], participant_id: params[:participant_id])

    if current_user.nil? || (! can? :update_other, Act::EventParticipant) && @event_participant.participant.user.id != current_user.id
      return render :not_allowed, locals: { desired: "upravovati " }
    end

    @event_participant.update_chosen()
    if @event_participant.update(event_participant_params)
      add_success "Přihláška na akci byla úspěšně změněna"
      redirect_to act_event_edit_participants_path(params[:event_id])
    else
      _find_event(params[:event_id])
      _get_participants()
      _filter_orgs()
      _filter_parts()
      @edit_participants = true
      render "act/events/show", status: :unprocessable_entity
    end
  end

  ##
  #  POST /act/event_participants/:event_id/delete
  #
  # Smaže přihlášku daného účastníka na danou akci
  #
  # *Params*
  # event:id:: událost, ke které se pozvánka vztahuje
  # participant_id:: účastnický účet, ke kterému se pozvánka vztahuje
  #
  # *Redirect* act_event_edit_participants_path
  def delete
    @event_participant = Act::EventParticipant.find_by(event_id: params[:event_id], participant_id: params[:participant_id])

    unless (can? :delete_other, Act::EventParticipant) || @event_participant.participant.user.id == current_user.id
      return render :not_allowed, locals: { desired: "upravovati " }
    end

    @event_participant.destroy

    add_success "Přihláška na akci byla úspěšně smazána"
    redirect_to act_event_edit_participants_path(params[:event_id])
  end

  ##
  #  POST /act/event_participants/:event_id/choose
  #
  # Změní přihlášku daného účastníka na danou akci. A to v tom ohledu, jestli daný účastník pojede jakožto účastník, nebo náhradník
  #
  # *Params*
  # event:id:: událost, ke které se pozvánka vztahuje
  # participant_id:: účastnický účet, ke kterému se pozvánka vztahuje
  # chosen:: jestli h chceme přihlásit jako účastníka nebo náhradníka
  #
  # *Provides*
  # @event_participant::
  #
  # *Redirect* act_event_edit_participants_path
  def choose
    @event_participant = Act::EventParticipant.find_by(event_id: params[:event_id], participant_id: params[:participant_id])
    unless (can? :update_other, Act::EventParticipant) || @event_participant.participant.user.id == current_user.id
      return render :not_allowed, locals: { desired: "upravovati " }
    end

    @event_participant.chosen = params[:chosen]
    @event_participant.save

    add_success "Přihláška na akci byla úspěšně změněna"
    redirect_to act_event_edit_participants_path(params[:event_id])
  end

  ##
  #  POST /act/events/:event_id/participants/:participant_id/role
  #
  # Přepne roli účasti (org <-> účastník). Vychází ze zobrazované role
  # (uložená, nebo odhad z ročníku) a uloží opak.
  #
  # *Redirect* act_event_edit_participants_path
  def set_role
    @event_participant = Act::EventParticipant.find_by(event_id: params[:event_id], participant_id: params[:participant_id])
    unless can? :update_other, Act::EventParticipant
      return render :not_allowed, locals: { desired: "upravovati " }
    end

    @event_participant.role = @event_participant.role_display == "org" ? "participant" : "org"
    @event_participant.save

    add_success "Role účasti změněna na #{@event_participant.role == 'org' ? 'org' : 'účastník'}"
    redirect_to act_event_edit_participants_path(params[:event_id])
  end

  private
    def event_participant_params
      params.require(:event_participant).permit(:status, :note, :place, :mass, :participant_info)
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

    def _get_participants()
      @participants_yes = Act::EventParticipant.where(event_id: @event.id).where(status: "yes").where(chosen: "participant").order(place: :asc, created_at: :asc)
      @participants_maybe = Act::EventParticipant.where(event_id: @event.id).where(status: "maybe").where(chosen: "participant").order(place: :asc, created_at: :asc)
      @participants_no = Act::EventParticipant.where(event_id: @event.id).where(status: "no").where(chosen: "participant").order(place: :asc, created_at: :asc)

      @substitutes_yes = Act::EventParticipant.where(event_id: @event.id).where(status: "yes").where(chosen: "substitute").order(place: :asc, created_at: :asc)
      @substitutes_maybe = Act::EventParticipant.where(event_id: @event.id).where(status: "maybe").where(chosen: "substitute").order(place: :asc, created_at: :asc)
      @substitutes_no = Act::EventParticipant.where(event_id: @event.id).where(status: "no").where(chosen: "substitute").order(place: :asc, created_at: :asc)
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

