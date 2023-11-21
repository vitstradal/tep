class EventParticipantsController < ApplicationController
  include ApplicationHelper
  def update
    @participant = EventParticipant.find_by("event_id=? AND scout_id=?", params[:event_id], params[:scout_id])
    
    @participant.update_chosen()
    if @participant.update(participant_params)
      _send_bonz_org(@participant.event.bonz_org, @participant, false)
      _send_bonz_parent(@participant.scout.parent_email, @participant, false)

      redirect_to edit_participants_event_path(params[:event_id])
    else
      render "events/edit_participants", status: :unprocessable_entity
    end
  end

  def delete
    @participant = EventParticipant.find_by("event_id=? AND scout_id=?", params[:event_id], params[:scout_id])
    @participant.destroy

    redirect_to event_path(params[:event_id])
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

  private
    def participant_params
      params.require(:event_participant).permit(:status, :note, :place, :mass, :scout_info)
    end
end

