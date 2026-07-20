  ##
  #   Třída sloužící k uchování záznmu o účasti člověka na akci spolu se všemi poznámkami, chce/nechce na mši apod.
  #
  # *Columns*
  #    t.integer  "event_id",         index: true
  #    t.integer  "participant_id",   index: true
  #    t.string   "status",           :default => "yes"
  #    t.string   "note",             :default => ""
  #    t.string   "place",            :default => ""
  #    t.string   "participant_info", :default => ""
  #    t.boolean  "mass",             :default => false
  #    t.string   "chosen",           :default => "none"
class Act::EventParticipant < ActiveRecord::Base
  belongs_to :event
  belongs_to :participant

  validates_associated :event
  validates_associated :participant

  STATUSES_OPTIONS = ["yes", "maybe", "no"]

  STATUS_TXT_LONG = { "yes" => "Jede", "maybe" => "Neví", "no" => "Nejede", "nvt" => "Nehlasoval" }

  CHOSEN_OPTIONS = ["participant", "substitute", "none"]
  CHOSEN_OPTIONS_TXT = { "participant" => "Účastník", "substitute" => "Náhradník", "none" => "Jiné" }

  validates :status, inclusion: { in: STATUSES_OPTIONS, message: "Účstník musí být buťo přihlášený, nebo neví, anebo nepřihlášený (yes, maybe, no)" }

  validates :chosen, inclusion: { in: CHOSEN_OPTIONS, message: "Účastník musí být buťo pozvaný, nebo náhradník, anebo none" }

  # Role účasti V DOBĚ AKCE ('org' | 'participant'); NULL = nezjištěno.
  # U starých akcí historická data nejsou — viz rake act:backfill_roles
  # a odhad z ročníku níže.
  ROLE_OPTIONS = ["org", "participant"]
  validates :role, inclusion: { in: ROLE_OPTIONS, message: "Role účasti je org, nebo participant" }, allow_nil: true

  ##
  # Odhad role z ročníku účastnického účtu (<= 9. ročník = účastník,
  # vyšší = org). *Returns* 'org' | 'participant' | nil (bez ročníku).
  def self.guess_role_from_grade(participant)
    return nil if participant.nil? || participant.grade.nil?
    participant.grade.to_i <= 9 ? "participant" : "org"
  end

  ##
  # Role k zobrazení: uložená, jinak odhad z ročníku (viz role_guessed?).
  def role_display
    role || Act::EventParticipant.guess_role_from_grade(participant)
  end

  ##
  # *Returns* true, když je zobrazovaná role jen odhad z ročníku
  # (uložená role chybí) — UI to má naznačit.
  def role_guessed?
    role.nil? && !Act::EventParticipant.guess_role_from_grade(participant).nil?
  end
  def go
    case status
    when "yes"
      "Y"
    when "maybe"
      "M"
    when "no"
      "N"
    else
      "-"
    end
  end

  ##
  # *Returns* čitelná hodnota stavu přihlášenosti
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

  def status_color
    case status
    when "yes"
      "#58d68d"
    when "maybe"
      "#f5b041"
    when "no"
      "#ec7063"
    else
      "#e0e0e0"
    end
  end

  ##
  # *Returns* čitelná hodnota stavu přihlášenosti v delší podobě
  def self.status_txt_long(event, participant)
    participant = get_event_participant(event, participant)
    begin
      return STATUS_TXT_LONG[participant.status]
    rescue
      return "Nejede"
    end
  end

  ##
  # *Returns* čitelná hodnota stavu účastník/náhradník
  def self.chosen_txt(event, participant)
    participant = get_event_participant(event, participant)
    begin
      return CHOSEN_OPTIONS_TXT[participant.chosen]
    rescue
      return "Nejede"
    end
  end

  def male?
    (! participant.nil?) && participant.male?
  end

  def org?
    (! participant.nil?) && participant.org?
  end

  def participant?
    return chosen == "participant"
  end

  def substitute?
    return chosen == "substitute"
  end

  ##
  # *Returns* čitelná hodnota stavu účastník/náhradník
  def self.role_txt(event, participant)
    begin
      return get_event_participant(event, participant).org? ? "Org" : "Účastník"
    rescue
      return "Účastník"
    end
  end

  ##
  # *Returns* event_participant pro danou akci a daný účastnický účet
  def self.get_event_participant(event, participant)
    return Act::EventParticipant.find_by(participant_id: participant.id, event_id: event.id)
  end

  ##
  # *Returns* stav účastník/náhradník/none
  def self.chosen(event, participant)
    begin
      get_event_participant(event, participant).chosen
    rescue
      return "none"
    end
  end

  ##
  # pokud není hodnota stavu účastník/náhradník/none rozumná, tak ji udělej rozumnou
  def update_chosen
    if status != "yes" and status != "maybe"
      chosen = "none"
    end
  end

  ##
  # *Returns* je třeba poslat mail?
  def self.mail_change?(old, new)
    care_if_changed = [:status, :place, :participant_info, :mass, :chosen]
    care_if_changed.each do |attr|
      if old.send(attr) != new.send(attr)
        return true
      end
    end

    return false
  end

  def par
     return 'org' if org?
     case chose
     when "participant"
       "par"
     when "substitute"
       "sub"
     when "none"
       "non"
     else
       "unk"
     end
  end
end
