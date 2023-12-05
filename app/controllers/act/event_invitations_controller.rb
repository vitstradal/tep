  ##
  #   Pozvánka na akci slouží k tomu, když se někam (např. na sous) zvou lidé. Je to propojení uživaelského účtu s akcí indikjící,
  #   jestli se daný participant může dané akce zúčastnit. A jestli může podat rovnou účastnickou přihlášku, nebo jestli musí náhradnickou.
  #   V případě, že má daná akce povolené volné přihlašování všech účastníků, pozvbývá tato pozvánka smyslu a není na ni brán ohled.
  #
class Act::EventInvitationsController < ActController

  ##
  #  POST /act/event_invitations/save
  #
  # Danou pozvánku buďto vytvoří, anebo upraví - v závislosti na tom, jestli už pro příslušnou kombinaci pevent-participant nějaká existuje
  #
  # *Params*
  # event_id:: událost, ke které se pozvánka vztahuje
  # participant_id:: účastnický účet, ke kterému se pozvánka vztahuje
  #
  # *Redirect* act_event_edit_invitations_path
  def save
    if ! can? :save, Act::EventInvitation
      render :not_allowed
      return
    end

    @invitation = Act::EventInvitation.find_by(event_id: params[:event_id], participant_id: params[:participant_id])

    if @invitation.nil?
      @invitation = Act::EventInvitation.new(invitation_params)
      if @invitation.save
        redirect_to act_event_edit_invitations_path(event_id: params[:event_id], chosen: params[:filter_chosen], role: params[:filter_role])
      else
        render "act/events/edit_invitations", status: :unprocessable_entity
      end
    else
      if @invitation.update(invitation_params)
        redirect_to act_event_edit_invitations_path(event_id: params[:event_id], chosen: params[:filter_chosen], role: params[:filter_role])
      else
        render "act/events/edit_invitations", status: :unprocessable_entity
      end
    end
  end

  ##
  #  POST /act/event_invitations/delete
  #
  # Danou pozvánku smaže
  #
  # *Params*
  # event_id:: událost, ke které se pozvánka vztahuje
  # participant_id:: účastnický účet, ke kterému se pozvánka vztahuje
  #
  # *Redirect* act_event_edit_invitations_path
  def delete
    if ! can? :delete, Act::EventInvitation
      render :not_allowed
      return
    end

    @invitation = Act::EventInvitation.find_by(event_id: params[:event_id], participant_id: params[:participant_id])
    @invitation.destroy

    redirect_to act_event_edit_invitations_path(params[:event_id])
  end
  
  private
    def invitation_params
      params.require(:event_invitation).permit!
    end
end
