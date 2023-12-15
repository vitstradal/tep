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
      participant = Act::EventParticipant.new
      participant.event_id = params[:event_id]
      participant.participant_id = params[:participant_id]
      participant.status = "yes"
      participant.chosen = params[:chosen]
    elsif params[:delete] != "true"
      if params[:chosen] && params[:chosen] != participant.chosen
        participant.chosen = params[:chosen]
        participant.save
      end
      redirect_to params[:path]
      return
    end

    if params[:delete] == "true"
      participant.destroy
      redirect_to params[:path]
      return
    end

    if participant.save
      redirect_to params[:path]
    else
      render params[:path], status: :unprocessable_entity
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
      redirect_to act_event_edit_participants_path(params[:event_id])
    else
      render act_event_edit_participants_path(params[:event_id]), status: :unprocessable_entity
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
    redirect_to act_event_edit_participants_path(params[:event_id])
  end

  private
    def event_participant_params
      params.require(:event_participant).permit(:status, :note, :place, :mass, :participant_info)
    end
end

