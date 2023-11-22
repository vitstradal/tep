class EventParticipant < ActiveRecord::Base
  belongs_to :event
  belongs_to :scout

  validates_associated :event
  validates_associated :scout

  def get_user
    User.find(user_id)
  end

  def show_status
    case status
    when "yes"
      "Ano"
    when "maybe"
      "Možná"
    when "no"
      "Ne"
    else
      "Stav nedefinován"
    end
  end

  def male?
    scout.male?
  end

  def org?
    scout.org?
  end

  def self.get_participant(scout, event)
    EventParticipant.find_by(scout_id: scout.id, event_id: event.id)
  end

  def update_chosen
    if status != "yes" and status != "maybe"
      chosen = "none"
    end
  end
end
