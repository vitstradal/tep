##
# Controller pro přihlašování se na akce
#
# VISIBLE_STATUSES:
# 'everyone'
# 'user'
# 'org'

require 'pp'

class EventsController < ApplicationController

  ##
  # GET /event/index
  #
  # Úvodní stránka k přihlašování na akce obecně
  #
  # *Provides*
  # @future_events::     všechny akce, které se budou konat (seřazené)
  # @past_evens::        všechny akce, které už se konaly (seřazené)
  # @event_category::    o jaký typ akce se jedná? (Event::CATEGORIES)
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

    args_future, args_past = Event::generate_sql(Scout::get_scout(current_user), @event_category, @enroll_status)

    @future_events = Event.find_by_sql(args_future)
    @past_events = Event.find_by_sql(args_past)
  end

  def show
    return unless _find_event(params[:id])

    if Scout::scouts?(current_user)
      @event_participant = EventParticipant.find_by("event_id=? AND scout_id=?", params[:id], Scout::scout_id(current_user))
      unless @event_participant
        @event_participant = EventParticipant.new
      end
    end

    @num_p_yes = @event.num_signed("yes", false, true)

    @already_happened = @event.event_end < Date.current
  end

  def enroll
    @event_participant = EventParticipant.find_by("event_id=? AND scout_id=?", params[:id], Scout::scout_id(current_user))
    if @event_participant
      @event_participant.update_chosen()
      if @event_participant.update(participant_params)
        redirect_to @event_participant.event
      else
        render :show, status: :unprocessable_entity
      end
    else
      @event_participant = EventParticipant.new(participant_params)    
      @event_participant.update_chosen()
      if @event_participant.save
        redirect_to Event.find(params[:id])
      else
        render :show, status: :unprocessable_entity
      end
    end
  end

  def new
    if not can? :create, Event
      render 'permission_denied', :locals => { :desired => "vytvářet nové" }
      return
    end

    @event = Event.new
  end

  def create
    if not can? :create, Event
      render 'permission_denied', :locals => { :desired => "vytvářet nové " }
      return
    end

    @event = Event.new(event_params)

    if @event.save
      redirect_to @event
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    if not can? :create, Event
      render 'permission_denied', :locals => { :desired => "editovat existující " }
      return
    end

    return unless _find_event(params[:id])
  end

  def edit_participants
    return unless _find_event(params[:id])

    if not can? :update, EventParticipant
      render 'permission_denied', :locals => { :desired => "editovat ostatní účastníky na " }
      return
    end

    @edit_participants = true
    render :show
  end

  def edit_invitations
    return unless _find_event(params[:id])

    @chosen = params[:chosen].nil? ? "ev" : params[:chosen]
    @role = (params[:role].nil? or params[:role] == 'p' or ! current_user.admin?) ? "p" : "o"

    @scouts = Scout::find_by_invitation(@event, @chosen, @role)

    if (can? :read, EventInvitation) and !(can? :create, EventInvitation)
      @editing = false
      render :edit_invitations
      return
    end

    if !(can? :create, EventInvitation)
      render 'permission_denied', :locals => { :desired => "zobrazovat ani editovat pozvánky na " }
      return
    end

    @editing = true
    render :edit_invitations
  end

  def update
    if not can? :create, Event
      render 'permission_denied', :locals => { :desired => "editovat existující " }
      return
    end

    return unless _find_event(params[:id])

    if @event.update(event_params)
      redirect_to @event
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def delete 
    if not can? :create, Event
      render 'permission_denied', :locals => { :desired => "mazat existující " }
      return
    end

    return unless _find_event(params[:id])
    @event.destroy

    redirect_to events_path
  end

  def filter
    redirect_to filter_events_path(params[:event_category], params[:enroll_status])
  end

  def display_scouts
    if !(can? :show_other, Scout)
      render 'not_allowed_to_show_others'
      return
    end

    return unless _find_event(params[:id])

    @event_participants = EventParticipant.find_by_sql(["SELECT * FROM event_participants WHERE event_id = ?", params[:event_id]])
    @filter_hashes = params[:filter_hashes].nil? ? Scout::ATTR_BOOL_TABLE : params[:filter_hashes]
  end

  private
    def event_params
      params.require(:event).permit!
    end

    def participant_params
      params.require(:event_participant).permit(:status, :note, :place, :mass, :scout_info)
    end

    def _find_event(id)
      @event = Event.find_by(id: id)
      if @event.nil?
        render :not_found
        return false
      end

      if Scout::scouts?(current_user) and @event.event_visible?(current_user)
        return true
      else
        render :not_allowed_to_show
        return false
      end
    end
end
