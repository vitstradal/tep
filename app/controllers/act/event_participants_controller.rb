class Act::EventParticipantsController < ActController
  def enroll_other
    @participant = Act::EventParticipant.find_by(event_id: params[:event_id], scout_id: params[:scout_id])

    if @participant.nil? && (! can? :create_other, Act::EventParticipant)
      render :not_allowed, locals: { desired: "vytvářeti " }
      return
    end

    if current_user.nil? || (! can? :update_other, Act::EventParticipant) && @participant.scout.user.id != current_user.id
      render :not_allowed, locals: { desired: "upravovati " }
      return
    end

    if @participant.nil?
      @participant = Act::EventParticipant.new(event_id: params[:event_id], scout_id: params[:scout_id], status: "yes", chosen: params[:chosen])
    elsif params[:delete] != "true"
      if ! params[:chosen].nil? && params[:chosen] != @participant.chosen
        @participant.chosen = params[:chosen]
        @participant.save
      end
      redirect_to params[:path]
      return
    end

    if params[:delete] == "true"
      @participant.destroy
      redirect_to params[:path]
      return
    end

    if @participant.save
      redirect_to params[:path]
    else
      render params[:path], status: :unprocessable_entity
    end
  end

  def update
    @participant = Act::EventParticipant.find_by(event_id: params[:event_id], scout_id: params[:scout_id])
    
    if current_user.nil? || (! can? :update_other, Act::EventParticipant) && @participant.scout.user.id != current_user.id
      render :not_allowed, locals: { desired: "upravovati " }
      return
    end

    @participant.update_chosen()
    if @participant.update(participant_params)
      redirect_to edit_event_participants_path(params[:event_id])
    else
      render edit_event_participants_path(params[:event_id]), status: :unprocessable_entity
    end
  end

  def delete
    @participant = Act::EventParticipant.find_by([params[:event_id], params[:scout_id]])

    if (! can? :delete_other, Act::EventParticipant) && @participant.scout.user.id != current_user.id
      render :not_allowed, locals: { desired: "upravovati " }
      return
    end

    @participant.destroy

    redirect_to edit_event_participants_path(params[:event_id])
  end

  def choose
    @participant = Act::EventParticipant.find_by([params[:event_id], params[:scout_id]])
    if (! can? :update_other, Act::EventParticipant) && @participant.scout.user.id != current_user.id
      render :not_allowed, locals: { desired: "upravovati " }
      return
    end
    pp @participant
    @participant.chosen = params[:chosen]
    @participant.save
    pp @participant

    redirect_to edit_event_participants_path(params[:event_id])
  end

  private
    def participant_params
      params.require(:event_participant).permit(:status, :note, :place, :mass, :scout_info)
    end
end

