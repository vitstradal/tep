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
  #
  def index
    @future_events = Event.where(["event_end >= ?", Time.current]).order(event_start: :desc)
    @past_events = Event.where(["event_end < ?", Time.current]).order(event_start: :desc)
  end

  ##
  # GET /event/:id/show
  #
  # Úvodní stránka k přihlašování na akce obecně
  #
  # *Provides*
  # @event
  # @event_participant
  #
  def show
    @event = Event.find(params[:id])
    unless current_user.nil?
      @event_participant = EventParticipant.find_by("event_id=? AND user_id=?", params[:id], current_user.id)
      unless @event_participant
        @event_participant = EventParticipant.new
      end
    end
  end

  def enroll
    @event_participant = EventParticipant.find_by("event_id=? AND user_id=?", params[:id], current_user.id)
    if @event_participant
      if @event_participant.update(enroll_params)
        redirect_to @event_participant.event
      else
        render :show, status: :unprocessable_entity
      end
    else
      @event_participant = EventParticipant.new(enroll_params)    
      if @event_participant.save
        redirect_to Event.find(params[:id])
      else
        render :show, status: :unprocessable_entity
      end
    end
  end

  def new
    @event = Event.new
  end

  def create
    @event = Event.new(event_params)

    if @event.save
      redirect_to @event
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @event = Event.find(params[:id])
  end

  def edit_participants
    @event = Event.find(params[:id])
    @edit_participants = true
    render :show
  end

  def update
    @event = Event.find(params[:id])

    if @event.update(event_params)
      redirect_to @event
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def delete 
    @event = Event.find(params[:id])
    @event.destroy

    redirect_to events_path
  end

  private
    def event_params
      params.require(:event).permit!
    end

    def enroll_params
      params.require(:event_participant).permit!
    end
end
