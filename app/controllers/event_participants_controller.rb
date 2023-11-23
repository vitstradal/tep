class EventParticipantsController < ApplicationController
  include ApplicationHelper
  def update
    @participant = EventParticipant.find_by("event_id=? AND scout_id=?", params[:event_id], params[:scout_id])
    
    @participant.update_chosen()
    if @participant.update(participant_params)
      redirect_to edit_event_participants_path(params[:event_id])
    else
      render edit_event_participants_path(params[:event_id]), status: :unprocessable_entity
    end
  end

  def delete
    @participant = EventParticipant.find_by([params[:event_id], params[:scout_id]])
    @participant.destroy

    redirect_to edit_event_participants_path(params[:event_id])
  end

  def choose
    @participant = EventParticipant.find_by([params[:event_id], params[:scout_id]])
    @participant.chosen = params[:chosen]
    @participant.save

    redirect_to edit_event_participants_path(params[:event_id])
  end

  private
    def participant_params
      params.require(:event_participant).permit(:status, :note, :place, :mass, :scout_info)
    end
end

