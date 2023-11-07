class EventParticipant < ActiveRecord::Base
  belongs_to :event
  belongs_to :scout

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
end
