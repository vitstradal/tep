class EventInvitation < ActiveRecord::Base
  belongs_to :event
  belongs_to :scout

  CHOSEN_OPTIONS = ["participant", "substitute", "none"]
  CHOSEN_OPTIONS_TXT = { "participant" => "Účastník", "substitute" => "Náhradník", "none" => "Nepozvaný" }

  validates :chosen, inclusion: { in: CHOSEN_OPTIONS, message: "Pozvaný musí být buťo pozvaný, nebo náhradník, anebo none" }
  validates_associated :event
  validates_associated :scout

  def self.chosen(event, scout)
    if event.nil? || scout.nil?
      return "none"
    end

     invitation = EventInvitation.find_by(event_id: event.id, scout: scout.id)
    if invitation.nil?
      return "none"
    else
      return invitation.chosen
    end
  end

  def self.chosen_txt(event, scout)
    return CHOSEN_OPTIONS_TXT[EventInvitation::chosen(event, scout)]
  end

  def self.chosen_p?(event, scout)
    return chosen(event, scout) == "participant"
  end

  def self.chosen_ps?(event, scout)
    return chosen(event, scout) == "participant" || chosen(event, scout) == "substitute"
  end
end
