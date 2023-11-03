##
# Controller pro přihlašování se na akce
#
# VISIBLE_STATUSES:
# 'everyone'
# 'user'
# 'org'

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
  #
  def show
    @event = Event.find(params[:id])
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
end
