##
# Třída reprezentující tabulku přihlášených a popř. nějaké krátké info ohledně akce.
#
#
require 'pp'

class StartBeforeEndValidator < ActiveModel::Validator
  def validate(record)
    if(record.event_start > record.event_end)
      record.errors[:event_end] << "Akce může končit až po svém začátku!"
    end
  end
end

class Event < ActiveRecord::Base
  has_many :event_participants, dependent: :destroy
  has_many :event_invitations, dependent: :destroy
  belongs_to :event_type

  validates :title, presence: true
  validates :event_start, presence: true
  validates :event_end, presence: true
  validates_with StartBeforeEndValidator
  validates :max_participants, presence: true, numericality: { only_integer: true, message: "musí být číslo" }


  VISIBLE_STATUSES = ['everyone', 'user', 'org']

  def self.category_filter(current_user)
    sql = "SELECT name, code, visible FROM event_categories ORDER BY idx"
    event_categories = ActiveRecord::Base.connection.execute(sql)
    event_categories = event_categories.select {|item| EventCategory::category_visible?(item["visible"], current_user) }
    result = event_categories.map { |category| [category["name"], category["code"]] }
    return result
  end

  def self.category_filter_all(current_user)
    categories = Event::category_filter(current_user)
    categories.append(['Všechny', 'ev'])
    return categories
  end

    # helper method for deciding whether the target event should be visible for the current user
  def event_visible?(user)
    pp EventInvitation::chosen_ps?(self, Scout::get_scout(user))
    pp (EventInvitation::chosen_ps?(self, Scout::get_scout(user)) || (! user.org? && !uninvited_participants_dont_see) || (user.org? && !uninvited_organisers_dont_see))
    if user.admin? || ((visible == 'ev' || (!user.nil? && (user.org? || visible=='user'))) && (EventInvitation::chosen_ps?(self, Scout::get_scout(user)) || (! user.org? && !uninvited_participants_dont_see) || (user.org? && !uninvited_organisers_dont_see)))
      true
    else
      false
    end
  end

  def date_str()
    if event_start == event_end
      event_start.strftime('%m/%d/%Y')
    else
      event_start.strftime('%m/%d/%Y') + " - " + event_end.strftime('%m/%d/%Y')
    end
  end

  def can_participate?(scout)
    if scout.org?
      return true
    end

    participant = EventParticipant::get_participant(scout, self)
    if ! participant.nil? && participant.chosen == "participant"
      return true
    end
    
    if num_signed("yes", false, true, true) >= max_participants
      return false
    end

    if !enable_only_specific_participants || EventInvitation::chosen_p?(self, scout)
      return true
    end

    return false
  end

  def can_substitute?(scout)
   participant = EventParticipant::get_participant(scout, self)

   if ! participant.nil? && participant.chosen == "substitute"
     return true
   end
    
   if !enable_only_specific_substitutes || EventInvitation::chosen_ps?(self, scout)
     return true
   end

   return false
  end

  def num_signed(status, orgs_only, children_only, participants_only=false)
    participants = EventParticipant.where(event_id: id).where(status: status)
    if orgs_only
      participants = participants.select { |p| p.org? }
    end

    if children_only
      participants = participants.select { |p| !(p.org?) }
    end

    if participants_only
      participants = participants.select { |p| p.chosen == "participant" }
    end

    participants.length()
  end

  def self.generate_sql(scout, event_category, enroll_status)
    query_start = "SELECT e.* FROM events e "

    common_enroll = "JOIN event_participants p ON (p.scout_id = ? AND p.event_id = e.id"

    case enroll_status
    when "ev"
      query_start += "WHERE "
    when "nvt"
      query_start += "LEFT " + common_enroll + ") WHERE "
    else
      query_start += "INNER " + common_enroll + " AND p.status = ?) WHERE "
    end

    if event_category != "ev"
      query_start += "e.event_category = ? AND "
    end

    case enroll_status
    when "ev"
      query_end = ""
    when "nvt"
      query_end = "AND p.id IS NULL "
    else
      query_end = "AND p.id IS NOT NULL "
    end

    query_end += "ORDER BY e.event_start DESC"

    future_query = query_start + "e.event_end >= ? " + query_end
    past_query = query_start + "e.event_end < ? " + query_end

    args_common = []

    if enroll_status != "ev"
      args_common.append(scout.id)
    end

    if not ["ev", "nvt"].member?(enroll_status)
      args_common.append(enroll_status)
    end

    if event_category != "ev"
      args_common.append(event_category)
    end

    args_common.append(Time.current.yesterday())

    args_future = [future_query] + args_common
    args_past = [past_query] + args_common

    return [args_future, args_past]
  end
end
