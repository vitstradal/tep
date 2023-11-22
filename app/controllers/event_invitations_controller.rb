class EventInvitationsController < ApplicationController
  def save
    @invitation = EventInvitation.find_by("event_id=? AND scout_id=?", params[:event_id], params[:scout_id])

    pp params
    if @invitation.nil?
      @invitation = EventInvitation.create(invitation_params)
      if @invitation.save
        redirect_to filter_invitations_event_path(id: params[:event_id], chosen: params[:filter_chosen], role: params[:filter_role])
      else
        render "events/edit_invitations", status: :unprocessable_entity
      end
    else
      if @invitation.update(invitation_params)
        redirect_to filter_invitations_event_path(id: params[:event_id], chosen: params[:filter_chosen], role: params[:filter_role])
      else
        render "events/edit_invitations", status: :unprocessable_entity
      end
    end
  end

  def delete
    @invitation = EventInvitation.find_by("event_id=? AND scout_id=?", params[:event_id], params[:scout_id])
    @invitation.destroy

    redirect_to edit_invitations_event_path(params[:event_id])
  end
  
  private
    def invitation_params
      params.require(:event_invitation).permit!
    end
end
