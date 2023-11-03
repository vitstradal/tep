class EventParticipant < ActiveRecord::Base
  belongs_to :event

  def get_user
    User.find(user_id)
  end
end
