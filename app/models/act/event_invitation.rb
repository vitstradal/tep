  ##
  #   Pozvánka na akci slouží k tomu, když se někam (např. na sous) zvou lidé. Je to propojení uživaelského účtu s akcí indikjící,
  #   jestli se daný participant může dané akce zúčastnit. A jestli může podat rovnou účastnickou přihlášku, nebo jestli musí náhradnickou.
  #   V případě, že má daná akce povolené volné přihlašování všech účastníků, pozvbývá tato pozvánka smyslu a není na ni brán ohled.
  #
  # *Columns*
  #    t.integer  "event_id",       index: true
  #    t.integer  "participant_id", index: true
  #    t.string   "chosen",         :default => "participant"
  
class Act::EventInvitation < ActiveRecord::Base
  belongs_to :event
  belongs_to :participant

  CHOSEN_OPTIONS = ["participant", "substitute", "none"]
  CHOSEN_OPTIONS_TXT = { "participant" => "Účastník", "substitute" => "Náhradník", "none" => "Nepozvaný" }

  validates :chosen, inclusion: { in: CHOSEN_OPTIONS, message: "Pozvaný musí být buťo pozvaný, nebo náhradník, anebo none" }
  validates_associated :event
  validates_associated :participant

  ##
  # *Returns* Jako co byl daný uživatel pozván na danou akci (účastník/náhradník/none)
  def self.chosen(event, participant)
    if event.nil? || participant.nil?
      return "none"
    end

     invitation = Act::EventInvitation.find_by(event_id: event.id, participant: participant.id)
    if invitation.nil?
      return "none"
    else
      return invitation.chosen
    end
  end

  ##
  # *Returns* Jako co byl daný uživatel pozván na danou akci (účastník/náhradník/none), v textové podobě určené pro uživatele
  def self.chosen_txt(event, participant)
    return CHOSEN_OPTIONS_TXT[Act::EventInvitation::chosen(event, participant)]
  end

  ##
  # *Returns* Byl daný uživatel pozván na danou akci jakožto účastník?
  def self.chosen_p?(event, participant)
    return chosen(event, participant) == "participant"
  end

  ##
  # *Returns* Byl daný uživatel pozván na danou akci jakožto náhradník?
  def self.chosen_ps?(event, participant)
    return chosen(event, participant) == "participant" || chosen(event, participant) == "substitute"
  end
end
