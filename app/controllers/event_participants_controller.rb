class EventParticipantsController < ApplicationController
require 'pp'
  def update
    @participant = EventParticipant.find_by("event_id=? AND scout_id=?", params[:event_id], params[:scout_id])
    
    if @participant.update(participant_params)
      redirect_to edit_participants_event_path(params[:event_id])
    else
      render "events/edit_participants", status: :unprocessable_entity
    end
  end

  def delete
    @participant = EventParticipant.find_by("event_id=? AND scout_id=?", params[:event_id], params[:scout_id])
    pp @participant
    @participant.destroy

    redirect_to event_path(params[:event_id])
  end

  private
    def participant_params
      params.require(:event_participant).permit(:status, :note)
    end
end

