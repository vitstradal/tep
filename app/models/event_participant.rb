class EventParticipant < ActiveRecord::Base
  belongs_to :event
  belongs_to :scout

  self.primary_keys = :event_id, :scout_id

  validates_associated :event
  validates_associated :scout

  STATUSES_OPTIONS = ["yes", "maybe", "no"]

  CHOSEN_OPTIONS = ["participant", "substitute", "none"]
  CHOSEN_OPTIONS_TXT = { "participant" => "Účastník", "substitute" => "Náhradník", "none" => "Nepozvaný" }

  validates :status, inclusion: { in: STATUSES_OPTIONS, message: "Účstník musí být buťo přihlášený, nebo neví, anebo nepřihlášený (yes, maybe, no)" }

  validates :chosen, inclusion: { in: CHOSEN_OPTIONS, message: "Účastník musí být buťo pozvaný, nebo náhradník, anebo none" }

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

  def self.get_participant(event, scout)
    EventParticipant.find_by(scout_id: scout.id, event_id: event.id)
  end

  def self.chosen(event, scout)
    get_participant(event, scout).chosen
  end

  def update_chosen
    if status != "yes" and status != "maybe"
      chosen = "none"
    end
  end

  def self.mail_change?(old, new)
    care_if_changed = [:status, :place, :scout_info, :mass, :chosen]
    care_if_changed.each do |attr|
      if old.send(attr) != new.send(attr)
        return true
      end
    end

    return false
  end
end
