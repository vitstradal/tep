class Act::EventInvitationsController < ActController
  def save
    if ! can? :save, Act::EventInvitation
      render :not_allowed
      return
    end

    @invitation = Act::EventInvitation.find_by("event_id=? AND scout_id=?", params[:event_id], params[:scout_id])

    if @invitation.nil?
      @invitation = Act::EventInvitation.create(invitation_params)
      if @invitation.save
        redirect_to filter_event_invitations_path(id: params[:event_id], chosen: params[:filter_chosen], role: params[:filter_role])
      else
        render "events/edit_invitations", status: :unprocessable_entity
      end
    else
      if @invitation.update(invitation_params)
        redirect_to filter_event_invitations_path(id: params[:event_id], chosen: params[:filter_chosen], role: params[:filter_role])
      else
        render "events/edit_invitations", status: :unprocessable_entity
      end
    end
  end

  def delete
    if ! can? :delete, Act::EventInvitation
      render :not_allowed
      return
    end

    @invitation = Act::EventInvitation.find_by("event_id=? AND scout_id=?", params[:event_id], params[:scout_id])
    @invitation.destroy

    redirect_to edit_event_invitations_path(params[:event_id])
  end
  
  private
    def invitation_params
      params.require(:event_invitation).permit!
    end
end