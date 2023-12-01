class Act::EventParticipant < ActiveRecord::Base
  belongs_to :event
  belongs_to :scout

  validates_associated :event
  validates_associated :scout

  STATUSES_OPTIONS = ["yes", "maybe", "no"]

  STATUS_TXT_LONG = { "yes" => "Jede", "maybe" => "Neví", "no" => "Nejede", "nvt" => "Nehlasoval" }

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

  def self.status_txt_long(event, scout)
    participant = get_participant(event, scout)
    begin
      return STATUS_TXT_LONG[participant.status]
    rescue
      return "Nejede"
    end
  end

  def self.chosen_txt(event, scout)
    participant = get_participant(event, scout)
    begin
      return CHOSEN_OPTIONS_TXT[participant.chosen]
    rescue
      return "Nejede"
    end
  end

  def male?
    ! scout.nil? || scout.male?
  end

  def org?
    ! scout.nil? && scout.org?
  end

  def self.role_txt(event, scout)
    begin
      return get_participant(event, scout).org? ? "Org" : "Účatník"
    rescue
      return "Účastník"
    end
  end

  def self.get_participant(event, scout)
    return Act::EventParticipant.find_by(scout_id: scout.id, event_id: event.id)
  end

  def self.chosen(event, scout)
    begin
      get_participant(event, scout).chosen
    rescue
      return "none"
    end
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
